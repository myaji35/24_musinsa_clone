module Trends
  class CharacterRecommender
    def initialize(today: Date.current)
      @week = today.beginning_of_week(:monday)
      @snapshots = TrendSnapshot.where(period_start: (@week - 7.weeks)..@week).to_a.group_by(&:series_name)
    end

    def call(character)
      keywords = character.wardrobe.to_s.split("·").map(&:strip).reject(&:blank?)
      @snapshots.filter_map do |name, snapshots|
        matched = keywords.select { |word| name.include?(word) || word.include?(name) }
        next if matched.empty?
        preferred = snapshots.select { |snapshot| snapshot.age_band == character.age_band }
        preferred = snapshots.select { |snapshot| snapshot.age_band.nil? } if preferred.empty?
        next if preferred.empty?
        # 출처/성별별 상대지수는 합산하지 않고, 주마다 가장 최근에 수집한 관측치를 사용한다.
        weekly = preferred.group_by(&:period_start).transform_values { |items| items.max_by { |item| [ item.imported_at, item.id ] }.ratio.to_f }
        recent = weekly.select { |week, _| week >= @week - 3.weeks }.values
        previous = weekly.select { |week, _| week < @week - 3.weeks }.values
        growth = if recent.any? && previous.any? && previous.sum.positive?
          ((recent.sum / recent.size) / (previous.sum / previous.size) - 1) * 100
        end
        insufficient = weekly.size < 2
        pattern = matched.map { |word| "%#{Product.sanitize_sql_like(word)}%" }
        products = Product.where(pattern.map { "(name LIKE ? ESCAPE '\\' OR category LIKE ? ESCAPE '\\')" }.join(" OR "), *pattern.flat_map { |word| [ word, word ] }).order(sales_count: :desc, id: :asc).limit(3)
        { series_name: name, growth: growth, latest: weekly.max_by(&:first).last,
          status: insufficient ? "데이터 부족" : (growth.nil? ? "비교 기간 부족" : "추천"),
          score: insufficient ? -Float::INFINITY : (growth || -Float::INFINITY), products: products }
      end.sort_by { |row| [ -row[:score], -row[:latest], row[:series_name] ] }.first(3)
    end
  end
end
