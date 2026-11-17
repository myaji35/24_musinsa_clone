require "test_helper"
require "minitest/mock"

class WechatClientTest < ActiveSupport::TestCase
  setup do
    @env = ENV.to_h.select { |key, _| key.start_with?("WECHAT_") }
    ENV.keys.grep(/^WECHAT_/).each { |key| ENV.delete(key) }
    ENV.update("WECHAT_APP_ID" => "test-app", "WECHAT_APP_SECRET" => "private-secret", "WECHAT_SEND_ENABLED" => "true")
    @contact = WechatContact.create!(account: accounts(:jieum), open_id: "client-test", last_inbound_at: Time.current)
    @calls = []
    @responses = []
    @cache = ActiveSupport::Cache::MemoryStore.new
    @http = ->(uri, payload) { @calls << [uri, payload]; @responses.shift || raise("Unexpected HTTP request") }
    @client = Wechat::Client.new(http: @http, cache: @cache)
  end

  teardown do
    ENV.keys.grep(/^WECHAT_/).each { |key| ENV.delete(key) }
    ENV.update(@env)
  end

  def send_text(**options)
    @client.send_text(contact: @contact, content: "新订单 / 신규 발주", **options)
  end

  test "stable token is POSTed and cached until five minutes before expiry" do
    @responses = [{ "access_token" => "cached", "expires_in" => 7200 }, { "errcode" => 0 }, { "errcode" => 0 }]
    assert_equal "sent", send_text.status
    travel 6899.seconds do
      assert_equal "sent", send_text.status
    end
    assert_equal 1, @calls.count { |uri, _| uri.path.end_with?("stable_token") }
    assert_equal "client_credential", @calls.first.last[:grant_type]
    @responses = [{ "access_token" => "new", "expires_in" => 7200 }, { "errcode" => 0 }]
    travel 6901.seconds do
      assert_equal "sent", send_text.status
    end
    assert_equal 2, @calls.count { |uri, _| uri.path.end_with?("stable_token") }
  end

  test "invalid tokens refresh and retry exactly once" do
    [40001, 42001, 40014].each do |code|
      @cache.clear
      @calls.clear
      @responses = [{ "access_token" => "old" }, { "errcode" => code }, { "access_token" => "new" }, { "errcode" => code, "errmsg" => "expired" }]
      assert_equal "failed", send_text.status
      assert_equal 4, @calls.size
      assert_equal true, @calls[2].last[:force_refresh]
      assert_includes @calls.last.first.query, "new"
    end
  end

  test "token refresh can recover a send without exposing either token" do
    @responses = [{ "access_token" => "old-secret-token" }, { "errcode" => 40001 },
      { "access_token" => "new-secret-token" }, { "errcode" => 0 }]
    assert_equal "sent", send_text.status
    assert_equal 4, @calls.size
  end

  test "disabled sending only persists and validates empty and oversized content" do
    ENV["WECHAT_SEND_ENABLED"] = "false"
    assert_equal "disabled", send_text.status
    assert_empty @calls
    ["", " ", "文" * 2001].each do |content|
      assert_no_difference "WechatMessage.count" do
        assert_raises(ActiveRecord::RecordInvalid) { @client.send_text(contact: @contact, content: content) }
      end
    end
    assert_equal "disabled", @client.send_text(contact: @contact, content: "文" * 2000).status
  end

  test "closed window uses PO template otherwise persists window_closed without HTTP" do
    @contact.update!(last_inbound_at: 48.hours.ago)
    assert_equal "window_closed", send_text.status
    assert_empty @calls
    ENV["WECHAT_PO_TEMPLATE_ID"] = "template-test"
    assert_equal "window_closed", send_text.status # Manual replies never use a PO template.
    @responses = [{ "access_token" => "cached" }, { "errcode" => 0, "msgid" => 1234 }]
    po = purchase_orders(:one)
    message = send_text(purchase_order: po, template_data: { number: { value: po.order_number } })
    assert_equal "sent", message.status
    assert_equal "template", message.msg_type
    assert_equal "1234", message.wechat_msg_id
    assert_equal "/cgi-bin/message/template/send", @calls.last.first.path
    assert_equal po.confirmation_url, @calls.last.last[:url]
  end

  test "unsubscribed contact cannot be sent a template" do
    ENV["WECHAT_PO_TEMPLATE_ID"] = "template-test"
    @contact.update!(subscribed: false)
    assert_equal "window_closed", send_text(purchase_order: purchase_orders(:one)).status
    assert_empty @calls
  end

  test "API errors and HTTP exceptions cannot disclose credentials" do
    @responses = [{ "access_token" => "token-secret" }, { "errcode" => 45015, "errmsg" => "private-secret rejected" }]
    message = send_text
    assert_equal "failed", message.status
    refute_includes message.error, "private-secret"
    client = Wechat::Client.new(http: ->(*) { raise "private-secret" }, cache: ActiveSupport::Cache::MemoryStore.new)
    refute_includes client.send_text(contact: @contact, content: "test").error, "private-secret"
  end

  test "associations cannot cross tenants" do
    foreign = Supplier.create!(account: accounts(:other), name: "Foreign", phone: "123")
    refute @contact.update(supplier: foreign)
    foreign_contact = WechatContact.create!(account: accounts(:other), open_id: "foreign")
    message = WechatMessage.new(account: accounts(:jieum), wechat_contact: foreign_contact, direction: "out", content: "test", msg_type: "text", status: "disabled")
    refute message.valid?
  end
end
