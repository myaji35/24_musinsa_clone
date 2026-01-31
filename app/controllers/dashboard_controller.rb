# Epic 4.3: 지역 트렌드 대시보드
# 익명 CRM 데이터를 활용한 지역별, 취향별 인사이트 제공
class DashboardController < ApplicationController
  # 대시보드 메인 페이지
  def index
    @total_customers = AnonyCustomer.count
    @total_orders = Order.count
    @total_revenue = Order.sum(:total_price)

    # 최근 7일 주문
    @recent_orders = Order.includes(:product, :variant, :anony_customer)
                          .where("created_at > ?", 7.days.ago)
                          .order(created_at: :desc)
                          .limit(10)

    # 지역별 판매 Top 5
    @regional_sales = regional_sales_data.first(5)

    # 인기 취향 태그 Top 10
    @top_preferences = top_preferences_data.first(10)
  end

  # 지역별 트렌드 분석
  def regional_trends
    @regional_sales = regional_sales_data
    @regional_preferences = regional_preference_data

    # 차트 데이터 (JSON)
    @chart_data = {
      labels: @regional_sales.map { |r| r[:zip_prefix] },
      sales: @regional_sales.map { |r| r[:total_sales] },
      orders: @regional_sales.map { |r| r[:order_count] }
    }
  end

  # 취향 태그 분석
  def preference_analysis
    @top_preferences = top_preferences_data
    @preference_trends = preference_trend_by_age

    # 카테고리별 취향 분석
    @category_preferences = category_preference_data
  end

  private

  # 지역별 판매 집계 (우편번호 앞 3자리)
  def regional_sales_data
    AnonyCustomer.joins(:orders)
                 .select("anony_customers.zip_prefix,
                          COUNT(orders.id) as order_count,
                          SUM(orders.total_price) as total_sales")
                 .where.not(zip_prefix: nil)
                 .group("anony_customers.zip_prefix")
                 .order("total_sales DESC")
                 .map do |record|
      {
        zip_prefix: record.zip_prefix,
        order_count: record.order_count,
        total_sales: record.total_sales.to_f
      }
    end
  end

  # 지역별 취향 태그 분석
  def regional_preference_data
    AnonyCustomer.where.not(zip_prefix: nil, preference_tags: nil)
                 .group_by(&:zip_prefix)
                 .transform_values do |customers|
      # 해당 지역의 모든 취향 태그를 합산
      merged_tags = customers.each_with_object({}) do |customer, tags|
        (customer.preference_tags || {}).each do |tag, count|
          tags[tag] = (tags[tag] || 0) + count
        end
      end
      merged_tags.sort_by { |_, count| -count }.first(5).to_h
    end
  end

  # 전체 인기 취향 태그 Top 10
  def top_preferences_data
    all_tags = AnonyCustomer.where.not(preference_tags: nil)
                            .pluck(:preference_tags)

    merged = all_tags.each_with_object({}) do |tags, result|
      (tags || {}).each do |tag, count|
        result[tag] = (result[tag] || 0) + count
      end
    end

    merged.sort_by { |_, count| -count }.first(10).map do |tag, count|
      { tag: tag, count: count }
    end
  end

  # 연령대별 취향 트렌드
  def preference_trend_by_age
    current_year = Date.today.year

    AnonyCustomer.where.not(birth_year: nil, preference_tags: nil)
                 .map do |customer|
      {
        age_group: age_group(current_year - customer.birth_year),
        preferences: customer.preference_tags
      }
    end
                 .group_by { |data| data[:age_group] }
                 .transform_values do |records|
      merged = records.each_with_object({}) do |record, tags|
        (record[:preferences] || {}).each do |tag, count|
          tags[tag] = (tags[tag] || 0) + count
        end
      end
      merged.sort_by { |_, count| -count }.first(3).to_h
    end
  end

  # 카테고리별 취향 태그 분석
  def category_preference_data
    Order.joins(:product, :anony_customer)
         .where.not("anony_customers.preference_tags": nil)
         .group("products.category")
         .select("products.category")
         .map do |record|
      category = record.category
      customers = AnonyCustomer.joins(:orders)
                               .joins("INNER JOIN products ON products.id = orders.product_id")
                               .where("products.category = ?", category)
                               .where.not(preference_tags: nil)
                               .distinct

      merged = customers.each_with_object({}) do |customer, tags|
        (customer.preference_tags || {}).each do |tag, count|
          tags[tag] = (tags[tag] || 0) + count
        end
      end

      {
        category: category,
        top_tags: merged.sort_by { |_, count| -count }.first(3).to_h
      }
    end
  end

  # 연령대 계산 (10대, 20대, 30대, 40대, 50대+)
  def age_group(age)
    case age
    when 0..19 then "10대"
    when 20..29 then "20대"
    when 30..39 then "30대"
    when 40..49 then "40대"
    else "50대+"
    end
  end
end
