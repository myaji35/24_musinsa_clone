# Epic 7: UCP Protocol API
# Universal Commerce Protocol - AI Agent 통합 API
module Api
  module V1
    class UcpController < ApplicationController
      # CSRF 토큰 검증 제외 (API 엔드포인트)
      skip_before_action :verify_authenticity_token

      # GET /api/v1/ucp/products
      # Query parameters: mood, tpo, category, limit
      def products
        # Build cache key from normalized params
        cache_key = build_cache_key

        # Cache entire response for 1 minute (reduced from 10 minutes)
        @response_data = Rails.cache.fetch(cache_key, expires_in: 1.minute) do
          @products = Product.includes(:variants).all

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
            {
              product_id: product.id,
              name: product.name,
              brand: product.brand,
              price: product.price,
              category: product.category,
              ai_attributes: parse_ai_attributes(product.ai_attributes),
              image_url: product.image_url,
              url: product_url(product, host: request.base_url),
              in_stock: product.variants.any? { |v| v.stock > 0 }
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

      def build_cache_key
        # Normalize params for consistent cache keys
        normalized_params = {
          mood: params[:mood]&.downcase&.strip,
          tpo: params[:tpo]&.downcase&.strip,
          category: params[:category]&.downcase&.strip,
          limit: [ params[:limit].to_i, 100 ].min
        }.compact

        "ucp/products/v3/#{Digest::MD5.hexdigest(normalized_params.to_json)}"
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
