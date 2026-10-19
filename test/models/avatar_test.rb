require "test_helper"

class AvatarTest < ActiveSupport::TestCase
  test "catalog contains the four selected avatars and supports handle lookup" do
    assert_equal %w[SeoHARIN KangUNA ChenMAYA OhDAEUN], Avatar.all.map(&:handle)
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

  test "every image exists in the served asset directory and is at most 300KB" do
    Avatar.all.each do |avatar|
      path = Rails.root.join("app/assets/images", avatar.image)
      assert path.file?, "이미지 없음: #{avatar.image}"
      assert_operator path.size, :<=, 300_000
      assert_equal "\xFF\xD8".b, File.binread(path, 2)
    end
  end
end
