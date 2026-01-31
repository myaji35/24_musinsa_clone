# Epic 4.2: 취향 태그 자동 수집 Job
# 주문 생성 시 자동으로 고객의 AI 속성 기반 취향 태그를 학습
class UpdatePreferenceTagsJob < ApplicationJob
  queue_as :default

  # Order ID를 받아서 고객의 preference_tags를 업데이트
  def perform(order_id)
    order = Order.find_by(id: order_id)
    return unless order # 주문이 삭제된 경우 무시

    customer = order.anony_customer
    product = order.product

    # 1. 카테고리 학습 (예: "아우터", "상의", "하의")
    customer.add_preference(product.category, 1) if product.category.present?

    # 2. 브랜드 학습
    customer.add_preference(product.brand, 1) if product.brand.present?

    # 3. AI 속성 학습
    learn_ai_attributes(customer, product)

    Rails.logger.info "✅ Preference tags updated for customer #{customer.uuid}: #{customer.preference_tags}"
  end

  private

  # AI 속성을 개별적으로 학습 (mood, tpo, fit_style, material_feel)
  def learn_ai_attributes(customer, product)
    return unless product.ai_attributes.is_a?(Hash)

    # Mood (예: "minimal", "vintage", "street")
    if product.ai_attributes["mood"].present?
      customer.add_preference("mood:#{product.ai_attributes['mood']}", 1)
    end

    # TPO (예: "daily", "outdoor", "office")
    if product.ai_attributes["tpo"].present?
      customer.add_preference("tpo:#{product.ai_attributes['tpo']}", 1)
    end

    # Fit Style (예: "slim", "oversized", "regular")
    if product.ai_attributes["fit_style"].present?
      customer.add_preference("fit:#{product.ai_attributes['fit_style']}", 1)
    end

    # Material Feel (예: "soft", "warm", "cool")
    if product.ai_attributes["material_feel"].present?
      customer.add_preference("material:#{product.ai_attributes['material_feel']}", 1)
    end
  end
end
