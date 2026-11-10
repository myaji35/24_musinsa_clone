require "net/http"
require "openssl"

module Seoullive
  class OrderWebhook
    class HttpError < StandardError; end

    NETWORK_ERRORS = [ Timeout::Error, SocketError, SystemCallError, IOError, EOFError,
                       OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::ProtocolError ].freeze

    def self.enabled?
      ENV["SEOULLIVE_ORDER_WEBHOOK_ENABLED"].in?(%w[1 true]) &&
        ENV["SEOULLIVE_ORDER_WEBHOOK_URL"].present? &&
        ENV["SEOULLIVE_ORDER_WEBHOOK_SECRET"].present?
    end

    def self.mask_name(name)
      first = name.to_s.strip.each_char.first
      return "고객" unless first

      first + (first.match?(/[가-힣ㄱ-ㅎㅏ-ㅣ]/) ? "*" : "***")
    end

    def self.payload(order)
      {
        event: "order.paid",
        order: {
          id: order.id.to_s, number: order.order_number,
          buyer_name: mask_name(order.shipping_address&.recipient_name),
          items: [ { product_id: order.product_id.to_s, name: order.product.name, quantity: order.quantity } ],
          total_amount: order.total_price.to_i, link_code: order.source_link_code
        }
      }
    end

    def self.deliver(order)
      body = JSON.generate(payload(order))
      uri = URI(ENV.fetch("SEOULLIVE_ORDER_WEBHOOK_URL"))
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["X-Jieum-Signature"] = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("SEOULLIVE_ORDER_WEBHOOK_SECRET"), body)}"
      request.body = body
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                open_timeout: 3, read_timeout: 5) { |http| http.request(request) }
      Rails.logger.info("order_id=#{order.id} code=#{response.code}")
      raise HttpError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response
    end
  end
end
