require "net/http"

module SheetPipeline
  class ImageFetcher
    MAX_BYTES = 20.megabytes
    MAX_REDIRECTS = 3
    TIMEOUT = 20

    def call(url, redirects = 0)
      uri = URI.parse(url)
      raise "HTTP URL 아님" unless %w[http https].include?(uri.scheme)
      raise "리다이렉트 초과" if redirects > MAX_REDIRECTS

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(uri.request_uri)) do |response|
          if response.is_a?(Net::HTTPRedirection)
            return call(URI.join(uri.to_s, response["location"]).to_s, redirects + 1)
          end
          raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          body = +"".b
          response.read_body do |chunk|
            body << chunk
            raise "20MB 초과" if body.bytesize > MAX_BYTES
          end
          return body
        end
      end
    end
  end
end
