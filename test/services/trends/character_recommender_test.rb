require "test_helper"

class Trends::CharacterRecommenderTest < ActiveSupport::TestCase
  def snapshot(name, week, ratio, age = nil)
    TrendSnapshot.create!(source: "datalab_csv", series_name: name, period_start: Date.new(2026, 10, 12) - week.weeks,
      ratio: ratio, age_band: age, imported_at: Time.current)
  end

  test "동일 연령대 우선 상승률 정렬과 판매순 후보 상품" do
    character = Character.new(wardrobe: "코트·니트·셔츠", age_band: 20)
    8.times do |week|
      snapshot("코트", week, week < 4 ? 40 : 20, 20)
      snapshot("코트", week, 100)
      snapshot("니트", week, week < 4 ? 30 : 20)
    end
    low = Product.create!(name: "코트 A", category: "외투", brand: "테스트", price: 1000, sales_count: 1)
    high = Product.create!(name: "코트 B", category: "외투", brand: "테스트", price: 1000, sales_count: 10)
    rows = Trends::CharacterRecommender.new(today: Date.new(2026, 10, 18)).call(character)
    assert_equal [ "코트", "니트" ], rows.map { |row| row[:series_name] }
    assert_in_delta 100, rows.first[:growth]
    assert_equal 40, rows.first[:latest]
    assert_equal [ high, low ], rows.first[:products].to_a
    assert_in_delta 50, rows.last[:growth]
  end

  test "한 주만 있으면 데이터 부족이며 오래된 데이터는 제외한다" do
    snapshot("셔츠", 0, 50)
    snapshot("코트", 9, 50)
    row = Trends::CharacterRecommender.new(today: Date.new(2026, 10, 18)).call(Character.new(wardrobe: "셔츠·코트", age_band: 30)).sole
    assert_equal "데이터 부족", row[:status]
    assert_nil row[:growth]
  end
end
