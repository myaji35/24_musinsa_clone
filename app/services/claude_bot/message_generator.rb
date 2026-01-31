# Epic 5.1: Claude API 연동 서비스
# 재고 부족 알림, 마케팅 메시지 등을 Claude AI로 자동 생성
module ClaudeBot
  class MessageGenerator
    CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"
    MODEL = "claude-3-5-sonnet-20241022" # 최신 Sonnet 모델

    # 재고 부족 알림 메시지 생성
    def self.generate_low_stock_alert(variant)
      product = variant.product
      current_stock = variant.stock || 0
      min_stock = variant.min_stock || 10

      prompt = <<~PROMPT
        당신은 의류 쇼핑몰 운영자입니다. 다음 상품의 재고가 부족하여 긴급 재입고가 필요합니다.

        **상품 정보:**
        - 상품명: #{product.name}
        - 브랜드: #{product.brand}
        - 카테고리: #{product.category}
        - 옵션: #{variant.color} / #{variant.size}
        - 현재 재고: #{current_stock}개
        - 최소 재고: #{min_stock}개
        - 가격: ₩#{product.price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}

        운영팀에게 보낼 재고 부족 알림 메시지를 작성해주세요. 다음 내용을 포함해야 합니다:
        1. 긴급도 표시
        2. 상품 및 옵션 정보
        3. 현재 재고 상황
        4. 권장 재입고 수량 (판매 추이 기반 추정)

        메시지는 간결하고 명확하게, 150자 이내로 작성하세요.
      PROMPT

      call_claude_api(prompt)
    end

    # 마케팅 메시지 생성 (Epic 6용)
    def self.generate_marketing_message(customer_preferences, product)
      prompt = <<~PROMPT
        당신은 패션 마케팅 전문가입니다. 고객의 취향에 맞는 상품 추천 메시지를 작성해야 합니다.

        **고객 취향 태그:**
        #{customer_preferences.map { |tag, count| "- #{tag}: #{count}회 구매" }.join("\n")}

        **추천 상품:**
        - 상품명: #{product.name}
        - 브랜드: #{product.brand}
        - 가격: ₩#{product.price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}

        고객의 취향을 반영한 개인화된 추천 메시지를 작성해주세요.
        메시지는 친근하고 설득력 있게, 100자 이내로 작성하세요.
      PROMPT

      call_claude_api(prompt)
    end

    # Claude API 호출 (실제 API 키가 필요)
    def self.call_claude_api(prompt)
      api_key = ENV["ANTHROPIC_API_KEY"]

      # API 키가 없으면 Mock 메시지 반환 (개발 환경용)
      return generate_mock_message(prompt) if api_key.blank?

      begin
        response = HTTP.auth("Bearer #{api_key}")
                       .headers("anthropic-version" => "2023-06-01", "content-type" => "application/json")
                       .post(CLAUDE_API_URL, json: {
                         model: MODEL,
                         max_tokens: 500,
                         messages: [
                           {
                             role: "user",
                             content: prompt
                           }
                         ]
                       })

        if response.status.success?
          result = JSON.parse(response.body)
          result.dig("content", 0, "text")
        else
          Rails.logger.error "Claude API Error: #{response.status} - #{response.body}"
          generate_mock_message(prompt)
        end
      rescue StandardError => e
        Rails.logger.error "Claude API Exception: #{e.message}"
        generate_mock_message(prompt)
      end
    end

    # Mock 메시지 생성 (API 키 없을 때 대체용)
    def self.generate_mock_message(prompt)
      if prompt.include?("재고 부족")
        "⚠️ [긴급] 재고 부족 알림: 해당 상품의 현재 재고가 최소 수준에 도달했습니다. 조속한 재입고를 권장합니다."
      elsif prompt.include?("마케팅")
        "안녕하세요! 고객님의 취향에 딱 맞는 신상품을 추천드립니다. 지금 확인해보세요!"
      else
        "자동 생성된 메시지입니다. (ANTHROPIC_API_KEY가 설정되지 않아 Mock 메시지를 사용합니다)"
      end
    end
  end
end
