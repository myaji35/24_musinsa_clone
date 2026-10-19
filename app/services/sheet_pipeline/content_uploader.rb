require "net/http"

module SheetPipeline
  class ContentUploader
    Result = Data.define(:status, :id, :reason) do
      def success?
        status.in?([ :success, :duplicate ])
      end

      def duplicate?
        status == :duplicate
      end
    end

    def upload(file_path:, product_id:, slot:, character_handle: nil, character_id: nil, kind: "cut", source_row: nil, sha256: nil)
      url = ENV["CONTENT_UPLOAD_URL"]
      token = ENV["CONTENT_UPLOAD_TOKEN"]
      return failure("CONTENT_UPLOAD_URL 또는 CONTENT_UPLOAD_TOKEN 미설정") if url.blank? || token.blank?

      uri = URI.parse(url)
      return failure("HTTP(S) URL이 필요합니다") unless uri.is_a?(URI::HTTP)

      fields = { product_id: product_id, character_handle: character_handle, character_id: character_id,
        kind: kind, slot: slot, source_row: source_row, sha256: sha256 }.compact.map { |key, value| [ key.to_s, value.to_s ] }
      response = File.open(file_path, "rb") do |file|
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{token}"
        request.set_form(fields + [ [ "file", file, { content_type: Marcel::MimeType.for(file, name: File.basename(file_path)) } ] ], "multipart/form-data")
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 60) { |http| http.request(request) }
      end
      body = JSON.parse(response.body)
      if response.code == "201" && body["id"].present?
        Result.new(status: :success, id: body["id"], reason: nil)
      elsif response.code == "200" && body["duplicate"] == true && body["id"].present?
        Result.new(status: :duplicate, id: body["id"], reason: nil)
      else
        failure("HTTP #{response.code}: #{body["errors"] || body["error"] || "잘못된 응답"}")
      end
    rescue StandardError => error
      failure("#{error.class}: #{error.message}")
    end

    private

    def failure(reason)
      Result.new(status: :failure, id: nil, reason: reason)
    end
  end
end
