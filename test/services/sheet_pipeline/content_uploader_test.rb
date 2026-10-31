require "test_helper"
require "minitest/mock"

class SheetPipeline::ContentUploaderTest < ActiveSupport::TestCase
  setup do
    @previous = ENV.values_at("CONTENT_UPLOAD_URL", "CONTENT_UPLOAD_TOKEN")
    ENV["CONTENT_UPLOAD_URL"] = "https://example.test/api/content_uploads"
    ENV["CONTENT_UPLOAD_TOKEN"] = "client-token"
  end

  teardown do
    ENV["CONTENT_UPLOAD_URL"], ENV["CONTENT_UPLOAD_TOKEN"] = @previous
  end

  test "multipart success duplicate and server errors" do
    [ [ "201", '{"id":7}', :success ], [ "200", '{"id":7,"duplicate":true}', :duplicate ],
      [ "422", '{"errors":["invalid"]}', :failure ], [ "401", '{"error":"unauthorized"}', :failure ],
      [ "503", '{"error":"upload token not configured"}', :failure ], [ "200", "{}", :failure ] ].each do |code, body, status|
      response = Struct.new(:code, :body).new(code, body)
      http = Object.new
      http.define_singleton_method(:request) do |request|
        raise "wrong authorization" unless request["Authorization"] == "Bearer client-token"
        raise "wrong content type" unless request.content_type == "multipart/form-data"
        response
      end
      Net::HTTP.stub(:start, ->(*_args, **_options, &block) { block.call(http) }) do
        result = upload
        assert_equal status, result.status
        assert_equal status != :failure, result.success?
        assert_equal status == :duplicate, result.duplicate?
        assert result.reason.present? if status == :failure
      end
    end
  end

  test "configuration network and malformed responses fail" do
    ENV.delete("CONTENT_UPLOAD_TOKEN")
    assert_not upload.success?
    ENV["CONTENT_UPLOAD_TOKEN"] = "client-token"
    Net::HTTP.stub(:start, ->(*) { raise IOError, "offline" }) do
      assert_includes upload.reason, "offline"
    end
    http = Object.new
    http.define_singleton_method(:request) { |_| Struct.new(:code, :body).new("201", "bad json") }
    Net::HTTP.stub(:start, ->(*_args, **_options, &block) { block.call(http) }) { assert_not upload.success? }
  end

  private

  def upload
    SheetPipeline::ContentUploader.new.upload(file_path: file_fixture("product.png"), product_id: 1, character_handle: "model", slot: 1)
  end
end
