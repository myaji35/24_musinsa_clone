require "net/http"

module Cutouts
  # 자체 호스팅 rembg 서버(BiRefNet 모델)로 상품 이미지의 배경을 지운다.
  # 외부 과금이 없어 월 호출 상한(IMAGE_PROCESSING_MONTHLY_LIMIT) 대상이 아니다.
  class RembgAdapter
    MODEL = "birefnet-general"
    DEFAULT_URL = "http://127.0.0.1:7000"
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 180
    PNG_SIGNATURE = "\x89PNG".b

    def self.provider_name
      "#{ProductImageProcessing::SELF_HOSTED_PREFIX}rembg/#{MODEL}"
    end

    def self.metered?
      false
    end

    def self.endpoint
      URI.join(ENV.fetch("REMBG_URL", DEFAULT_URL), "/api/remove")
    end

    def initialize(record)
      @product = record.product
    end

    def call
      raise "원본 이미지가 없습니다" unless @product.image.attached?

      png = request_cutout(@product.image.download, @product.image.filename.to_s)
      @product.cutout_image.attach(io: StringIO.new(png), filename: "product-#{@product.id}-cutout.png", content_type: "image/png")
      { cost_cents: 0 }
    end

    private

    def request_cutout(bytes, filename)
      uri = self.class.endpoint
      request = Net::HTTP::Post.new(uri)
      request.set_form([ [ "file", StringIO.new(bytes), { filename: filename } ], [ "model", MODEL ] ], "multipart/form-data")

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
        open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) { |http| http.request(request) }
      raise "rembg 서버 응답 오류(HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

      body = response.body.to_s.b
      raise "rembg 응답이 PNG가 아닙니다" unless body.start_with?(PNG_SIGNATURE)

      body
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError, Net::OpenTimeout => e
      raise "rembg 서버에 연결할 수 없습니다(#{uri}): #{e.class}"
    end
  end
end
