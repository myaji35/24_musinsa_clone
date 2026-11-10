# Epic 7: UCP Protocol API
# Universal Commerce Protocol - AI Agent 통합 API
module Api
  module V1
    class UcpController < ApplicationController
      skip_before_action :require_admin

      # CSRF 토큰 검증 제외 (API 엔드포인트)
      skip_before_action :verify_authenticity_token
      before_action :authenticate_api_key

      # GET /api/v1/ucp/products
      # Query parameters: mood, tpo, category, limit
      def products
        # Build cache key from normalized params
        cache_key = build_cache_key

        # Cache entire response for 1 minute (reduced from 10 minutes)
        @response_data = Rails.cache.fetch(cache_key, expires_in: 1.minute) do
          @products = Product.published.includes(:variants).with_attached_image

          # AI 감성 필터 (mood)
          if params[:mood].present?
            @products = @products.by_mood(params[:mood])
          end

          # TPO 필터
          if params[:tpo].present?
            @products = @products.by_tpo(params[:tpo])
          end

          # 카테고리 필터
          if params[:category].present?
            @products = @products.where(category: params[:category])
          end

          # 제한 수량 (기본 20, 최대 100)
          limit = [ params[:limit].to_i, 100 ].min
          limit = 20 if limit <= 0
          @products = @products.limit(limit)

          # Build response data
          products_data = @products.map do |product|
            spec = product.product_spec
            image_url = product.image_url
            if product.image.attached?
              begin
                image_url = Rails.application.routes.url_helpers.rails_blob_url(product.image, host: request.base_url)
              rescue StandardError
                image_url = product.image_url
              end
            end

            {
              product_id: product.id,
              name: product.name,
              brand: product.brand,
              price: product.price,
              category: product.category,
              ai_attributes: parse_ai_attributes(product.ai_attributes),
              image_url: image_url,
              url: product_url(product, host: request.base_url),
              in_stock: product.variants.any? { |v| v.stock.to_i > 0 },
              stock_total: product.variants.sum { |variant| variant.stock.to_i },
              variants: product.variants.map do |variant|
                {
                  variant_id: variant.id,
                  sku_code: variant.sku_code,
                  color: variant.color,
                  size: variant.size,
                  stock: variant.stock.to_i,
                  in_stock: variant.stock.to_i > 0
                }
              end,
              measurements: product_measurements(spec),
              materials: ProductSpec::MATERIAL_FIELDS.index_with { |field| spec.material(field) }.compact_blank,
              fit: ProductSpec::FIT_OPTIONS.keys.index_with { |field| spec.fit(field) }.compact_blank,
              care_instructions: care_instructions(product)
            }
          end

          {
            status: "success",
            count: products_data.count,
            products: products_data,
            cached_at: Time.current.iso8601
          }
        end

        render json: @response_data, status: :ok
      end

      private

      def product_measurements(spec)
        items = spec.visible_measurement_items
        spec.sizes.each_with_object({}) do |size, measurements|
          values = items.index_with { |item| spec.measurement(size, item) }.compact_blank
          measurements[size] = values if values.present?
        end
      end

      def care_instructions(product)
        value = product.info_notice_value("세탁방법")
        value if value.present? && !value.start_with?("TODO:")
      end

      def authenticate_api_key
        expected = ENV["UCP_API_KEY"]
        if expected.blank?
          Rails.logger.error "UCP_API_KEY 미설정 — API 접근 거부"
          render json: { status: "error", message: "API가 구성되지 않았습니다." }, status: :service_unavailable
          return
        end
        provided = request.headers["X-API-Key"].presence || params[:api_key].presence
        unless provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided.to_s, expected.to_s)
          render json: { status: "error", message: "유효하지 않은 API 키입니다." }, status: :unauthorized
        end
      end

      def build_cache_key
        # Normalize params for consistent cache keys
        normalized_params = {
          mood: params[:mood]&.downcase&.strip,
          tpo: params[:tpo]&.downcase&.strip,
          category: params[:category]&.downcase&.strip,
          limit: [ params[:limit].to_i, 100 ].min
        }.compact

        "ucp/products/v4/#{Digest::MD5.hexdigest(normalized_params.to_json)}"
      end

      def parse_ai_attributes(attributes)
        # 이관 전 문자열 데이터도 안전하게 처리
        attributes = JSON.parse(attributes) if attributes.is_a?(String)
        return {} unless attributes.is_a?(Hash)

        attributes = attributes.stringify_keys
        %w[mood tpo].each do |key|
          attributes[key] = Array(attributes[key]).reject(&:blank?) if attributes.key?(key)
        end
        attributes
      rescue JSON::ParserError
        {}
      end
    end
  end
end
