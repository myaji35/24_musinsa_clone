require "test_helper"
require "minitest/mock"
require_relative "../../support/seoullive_webhook_env"

class Seoullive::OrderWebhookTest < ActiveSupport::TestCase
  include SeoulliveWebhookEnv

  test "masking follows receiver rules" do
    { "김지은" => "김*", "Jane" => "J***", "" => "고객", nil => "고객", "  " => "고객", " ㄱ " => "ㄱ*" }.each do |name, expected|
      assert_equal expected, Seoullive::OrderWebhook.mask_name(name)
    end
  end

  test "payload masks names and includes attribution and amounts" do
    order = orders(:one)
    address = shipping_addresses(:one)
    address.update!(recipient_name: "김지은")
    order.update!(shipping_address: address, source_link_code: "Abc234xy")
    payload = Seoullive::OrderWebhook.payload(order)
    assert_not_includes JSON.generate(payload), "김지은"
    assert_equal "order.paid", payload[:event]
    data = payload[:order]
    assert_equal order.id.to_s, data[:id]
    assert_equal order.order_number, data[:number]
    assert_equal "김*", data[:buyer_name]
    assert_equal "Abc234xy", data[:link_code]
    assert_equal 39800, data[:total_amount]
    assert_instance_of Integer, data[:total_amount]
    assert_equal [ { product_id: order.product_id.to_s, name: order.product.name, quantity: 2 } ], data[:items]
    order.update!(shipping_address: nil)
    assert_equal "고객", Seoullive::OrderWebhook.payload(order)[:order][:buyer_name]
  end

  test "HTTP uses exact body signature TLS and timeouts" do
    with_webhook_env do
      http = Minitest::Mock.new
      http.expect :request, Net::HTTPOK.new("1.1", "200", "OK") do |request|
        assert_equal "application/json", request["Content-Type"]
        assert_equal "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", "test-secret", request.body)}", request["X-Jieum-Signature"]
        assert_equal JSON.generate(Seoullive::OrderWebhook.payload(orders(:one))), request.body
        true
      end
      start = ->(host, port, **options, &block) do
        assert_equal "example.invalid", host
        assert_equal 443, port
        assert_equal({ use_ssl: true, open_timeout: 3, read_timeout: 5 }, options)
        block.call(http)
      end
      Net::HTTP.stub(:start, start) { Seoullive::OrderWebhook.deliver(orders(:one)) }
      http.verify
    end
  end

  test "non success responses and timeouts raise" do
    with_webhook_env do
      http = Object.new
      http.define_singleton_method(:request) { |_| Net::HTTPInternalServerError.new("1.1", "500", "Error") }
      Net::HTTP.stub(:start, ->(*, **, &block) { block.call(http) }) do
        assert_raises(Seoullive::OrderWebhook::HttpError) { Seoullive::OrderWebhook.deliver(orders(:one)) }
      end
      Net::HTTP.stub(:start, ->(*, **) { raise Net::ReadTimeout }) do
        assert_raises(Net::ReadTimeout) { Seoullive::OrderWebhook.deliver(orders(:one)) }
      end
    end
  end
end
