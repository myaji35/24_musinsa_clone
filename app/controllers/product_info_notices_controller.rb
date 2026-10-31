class ProductInfoNoticesController < ApplicationController
  def index
    products = Product.order(status: :desc, name: :asc, id: :asc).to_a
    @total_count = products.size
    @incomplete_count = products.count { |product| !product.info_notice_complete? }
    @products = params[:all] == "1" ? products : products.reject(&:info_notice_complete?)
  end

  def update_all
    notices = params.fetch(:notices, ActionController::Parameters.new)
    saved_count = 0
    Product.transaction do
      if notices.is_a?(ActionController::Parameters)
        notices.each_pair do |id, values|
          next unless id.match?(/\A[0-9]+\z/) && values.is_a?(ActionController::Parameters)

          product = Product.find_by(id: id)
          next unless product

          attributes = values.permit(*Product::INFO_NOTICE_FIELDS).to_h.transform_values { |value| value.to_s.strip }
          next if attributes.empty?

          # 상품정보만 바꾼다. 다른 항목의 옛 데이터 검증 실패로 일괄 저장 전체가 막히지 않게 검증은 건너뛴다(ISS-152)
          merged = (product.info_notice || {}).merge(attributes)
          next if merged == (product.info_notice || {})

          product.info_notice = merged
          product.save!(validate: false)
          saved_count += 1
        end
      end
    end
    remaining_count = Product.all.count { |product| !product.info_notice_complete? }
    redirect_to product_info_notices_path,
      notice: "#{saved_count}개 상품의 상품정보를 저장했습니다. 남은 미완성 상품 #{remaining_count}개"
  end
end
