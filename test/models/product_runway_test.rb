require "test_helper"

class ProductRunwayTest < ActiveSupport::TestCase
  setup do
    @product = products(:one)
  end

  test "영상 허용 형식과 100MB 경계값" do
    %w[video/mp4 video/webm video/quicktime].each do |type|
      @product.runway_video.attach(io: StringIO.new("video"), filename: "runway", content_type: type, identify: false)
      assert @product.valid?, @product.errors.full_messages.join
    end
    @product.runway_video.blob.byte_size = 100.megabytes
    assert @product.valid?
    @product.runway_video.blob.byte_size = 100.megabytes + 1
    assert_not @product.valid?
    assert @product.errors[:runway_video].any?
  end

  test "영상 이외 형식은 거절한다" do
    @product.runway_video.attach(io: StringIO.new("text"), filename: "runway.txt", content_type: "text/plain", identify: false)
    assert_not @product.valid?
    assert @product.errors[:runway_video].any?
  end

  test "캐릭터 연결은 선택 사항이고 캐릭터 삭제 시 해제된다" do
    assert @product.valid?
    character = Character.create!(name: "강유나", handle: "runway-model", status: "active")
    @product.update!(worn_character: character)
    assert_includes character.worn_products, @product
    character.destroy!
    assert_nil @product.reload.worn_character_id
  end
end
