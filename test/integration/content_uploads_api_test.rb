require "test_helper"

class ContentUploadsApiTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["CONTENT_UPLOAD_TOKEN"]
    ENV["CONTENT_UPLOAD_TOKEN"] = "test-upload-token"
    @character = Character.create!(name: "모델", handle: "api-model")
  end

  teardown do
    ENV["CONTENT_UPLOAD_TOKEN"] = @previous_token
  end

  test "unconfigured token returns 503" do
    ENV.delete("CONTENT_UPLOAD_TOKEN")
    send_upload
    assert_response :service_unavailable
    assert_equal "upload token not configured", response.parsed_body["error"]
  end

  test "invalid token returns 401" do
    send_upload(token: "wrong")
    assert_response :unauthorized
  end

  test "new upload and duplicate return real ids" do
    assert_difference("ContentUpload.count", 1) { send_upload }
    assert_response :created
    id = response.parsed_body["id"]
    assert ContentUpload.find(id).file.attached?
    assert_no_difference("ContentUpload.count") { send_upload }
    assert_response :ok
    assert_equal({ "id" => id, "duplicate" => true }, response.parsed_body)
  end

  test "invalid format returns 422" do
    send_upload(file: Rack::Test::UploadedFile.new(file_fixture("datalab_trends.csv"), "text/csv"))
    assert_response :unprocessable_entity
  end

  test "checksum mismatch returns 422" do
    send_upload(sha256: "wrong")
    assert_response :unprocessable_entity
    assert response.parsed_body["errors"].any?
  end

  test "missing file and invalid association return 422" do
    send_upload(file: nil)
    assert_response :unprocessable_entity
    send_upload(character_handle: "missing")
    assert_response :unprocessable_entity
  end

  test "slot replacement creates a new record and invalid replacement preserves old" do
    send_upload
    old = ContentUpload.last
    file = Tempfile.new([ "replacement", ".png" ])
    file.binmode
    file.write(File.binread(file_fixture("product.png")) + "different")
    file.flush
    send_upload(file: Rack::Test::UploadedFile.new(file.path, "image/png"))
    assert_response :created
    assert_not ContentUpload.exists?(old.id)
    assert_equal 1, ContentUpload.where(product: products(:one), character: @character).count
    send_upload(slot: 4)
    assert_response :unprocessable_entity
    assert_equal 1, ContentUpload.where(product: products(:one), character: @character).count
  ensure
    file&.close!
  end

  private

  def send_upload(token: "test-upload-token", **overrides)
    post api_content_uploads_path, params: {
      product_id: products(:one).id, character_handle: @character.handle, kind: "cut", slot: 1,
      file: Rack::Test::UploadedFile.new(file_fixture("product.png"), "image/png")
    }.merge(overrides), headers: { "Authorization" => "Bearer #{token}" }
  end
end
