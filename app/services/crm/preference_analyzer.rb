# Service for analyzing customer preferences
module CRM
  class PreferenceAnalyzer < ApplicationService
    def initialize(anony_customer:)
      @customer = anony_customer
    end

    def call
      return failure("고객 정보가 없습니다") unless @customer

      success({
        customer_uuid: @customer.uuid,
        top_preferences: @customer.top_preferences(5),
        total_orders: @customer.orders.count,
        total_purchases: calculate_total_purchases,
        recommended_products: recommend_products,
        preference_summary: generate_summary
      })
    rescue StandardError => e
      Rails.logger.error "PreferenceAnalyzer Error: #{e.message}"
      failure("취향 분석 실패: #{e.message}")
    end

    private

    def calculate_total_purchases
      @customer.orders.sum(:total_price) || 0
    end

    def recommend_products
      # 고객의 상위 취향 태그 기반 상품 추천
      top_tags = @customer.top_preferences(3).keys

      if top_tags.any?
        # ai_attributes에서 해당 태그와 매칭되는 상품 검색
        Product.where("ai_attributes LIKE ?", "%#{top_tags.first}%")
               .limit(5)
               .pluck(:id, :name, :brand, :price)
               .map do |id, name, brand, price|
                 { id: id, name: name, brand: brand, price: price }
               end
      else
        []
      end
    end

    def generate_summary
      tags = @customer.preference_tags || {}
      total_count = tags.values.sum

      if total_count == 0
        "아직 구매 이력이 없습니다."
      else
        top_tag = tags.max_by { |_k, v| v }&.first
        "주요 취향: #{top_tag} (총 #{total_count}회 구매)"
      end
    end
  end
end
