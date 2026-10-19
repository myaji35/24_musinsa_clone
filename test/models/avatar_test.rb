require "test_helper"

class AvatarTest < ActiveSupport::TestCase
  test "catalog contains the ten selected avatars and supports handle lookup" do
    assert_equal 10, Avatar.all.size
    assert_equal %w[SeoHARIN TanakaMIO ParkJADE YunCHAEI MoreauLEA HanSOYUL KangUNA ChenMAYA OhDAEUN SoERIN], Avatar.all.map(&:handle)
    assert_equal "서하린", Avatar.find("SeoHARIN").name
    assert_nil Avatar.find("unknown")
    assert_nil Avatar.find(nil)
  end

  test "metadata reuses character measurements and records provenance" do
    characters = YAML.safe_load_file(Rails.root.join("config/characters.yml"))
    Avatar.all.each do |avatar|
      character = characters.find { |entry| entry["handle"] == avatar.handle }
      %w[name body_type height_cm top_size bottom_size].each do |attribute|
        assert_equal character.fetch(attribute), avatar.public_send(attribute)
      end
      assert_equal "female", avatar.gender
      assert avatar.source.start_with?("persona/")
      assert_includes avatar.license, "persona/cost-log.jsonl"
      assert_equal "기록 없음(persona 작업물)", avatar.generator
    end
  end

  test "every image exists in the served asset directory and is a JPEG within its size limit" do
    Avatar.all.each do |avatar|
      { image: 150_000, card_image: 40_000 }.each do |attribute, limit|
        image = avatar.public_send(attribute)
        expected_path = "avatars/#{avatar.handle}#{attribute == :card_image ? '-card' : ''}.jpg"
        assert_equal expected_path, image
        path = Rails.root.join("app/assets/images", image)
        assert path.file?, "이미지 없음: #{image}"
        assert_operator path.size, :<=, limit
        assert_equal "\xFF\xD8".b, File.binread(path, 2)
      end
    end
  end
end
