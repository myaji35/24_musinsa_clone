require "test_helper"

class ContentUploadTest < ActiveSupport::TestCase
  setup do
    @character = Character.create!(name: "모델", handle: "upload-model")
    @upload = ContentUpload.new(product: products(:one), character: @character, kind: "cut", slot: 1, sha256: "a" * 64)
    @upload.file.attach(io: File.open(file_fixture("product.png")), filename: "cut.png", content_type: "image/png")
  end

  test "valid cut and required associations" do
    assert @upload.valid?
    @upload.product = nil
    @upload.character = nil
    assert_not @upload.valid?
  end

  test "kind slot file type and size validation" do
    @upload.kind = "video"
    @upload.slot = 4
    @upload.file.blob.content_type = "text/plain"
    @upload.file.blob.byte_size = 10.megabytes + 1
    assert_not @upload.valid?
    [ :kind, :slot, :file ].each { |key| assert @upload.errors[key].any? }
  end

  test "file is required and checksum unique" do
    @upload.save!
    other = @upload.dup
    assert_not other.valid?
    assert other.errors[:sha256].any?
    assert other.errors[:file].any?
  end
end
