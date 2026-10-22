require "test_helper"

class CharacterTest < ActiveSupport::TestCase
  test "인트로는 정본 스타일축 순서 다음 연령대순으로 전체 캐릭터를 정렬한다" do
    attributes = YAML.load_file(Rails.root.join("config/characters.yml"))
    attributes.reverse_each { |row| Character.create!(row) }

    expected = attributes.map { |row| row.fetch("style_axis") }.uniq.flat_map do |axis|
      attributes.select { |row| row.fetch("style_axis") == axis }.sort_by { |row| [ row.fetch("age_band"), row.fetch("handle") ] }.map { |row| row.fetch("handle") }
    end
    assert_equal 20, Character.for_intro.size
    assert_equal expected, Character.for_intro.map(&:handle)
    assert_equal %w[SeoHARIN HanSOYUL MoonSEOJIN JungHYEWON TanakaMIO], expected.first(5)
  end

  test "키와 신발 사이즈는 허용 범위의 정수여야 한다" do
    character = Character.new(name: "테스트", handle: "Test", status: "planned")

    { height_cm: [ 139, 191, 160.5 ], shoe_mm: [ 209, 281, 235.5 ] }.each do |attribute, invalid_values|
      invalid_values.each do |value|
        character.public_send("#{attribute}=", value)
        assert_not character.valid?, "#{attribute}=#{value} should be invalid"
      end
      character.public_send("#{attribute}=", nil)
    end

    assert character.valid?
    character.height_cm = 140
    character.shoe_mm = 280
    assert character.valid?
    character.height_cm = 190
    character.shoe_mm = 210
    assert character.valid?
  end

  test "캐릭터 정본 스무 명의 체형 수치가 모두 유효하다" do
    characters = YAML.load_file(Rails.root.join("config/characters.yml"))
    assert_equal 20, characters.size

    characters.each do |attributes|
      %w[height_cm top_size bottom_size shoe_mm body_type].each do |field|
        assert attributes.key?(field), "#{attributes.fetch('handle')} is missing #{field}"
        assert attributes.fetch(field).present?, "#{attributes.fetch('handle')} has blank #{field}"
      end
      assert_kind_of String, attributes.fetch("bottom_size")
      assert Character.new(attributes).valid?, "#{attributes.fetch('handle')} is invalid"
    end
  end

  test "정본 동기화는 스무 명을 멱등으로 유지한다" do
    Rails.application.load_tasks
    2.times { Rake::Task["characters:sync"].reenable; Rake::Task["characters:sync"].invoke }
    assert_equal 20, Character.count
    assert_equal [ "KangUNA" ], Character.active.pluck(:handle)
  end
end
