require "base64"

module ProductAnalyses
  class Analyzer < ApplicationService
    SYSTEM = <<~TEXT.freeze
      JIEUN은 연령별 AI 캐릭터 20명이 의류별 숏폼(유튜브·인스타·틱톡)으로 자사몰에 유입시키는 쇼핑몰이다.
      상품 이미지와 정보를 보고 가장 잘 맞는 캐릭터 1명과 차선 1명, 홍보 컨셉을 고른다.
      컨셉 앵글: peer_fit(동년배 착용감), motion_fit(움직여야 보이는 핏·소재), privacy(덜 묻는 쇼핑), other.
      hook_line은 영상 첫 2초 자막으로 20자 이내, 밝고 경쾌하게 쓴다. 최상급·수치·'1위' 같은 입증 불가 표현은 금지한다.
      이미지에서 확인 불가한 것은 추측하지 말고 attributes에 null로 둔다.
      숫자 매출 예측은 하지 않는다. KPI는 시스템이 계산한다. reasoning은 3문장 이내로 쓴다.
    TEXT
    STYLE_AXES = %w[미니멀·오피스 캐주얼·데일리 스트리트·스포티 페미닌·로맨틱 트렌드·하이패션].freeze
    SCHEMA = {
      type: "object", additionalProperties: false,
      properties: {
        style_axis: { type: "string", enum: STYLE_AXES },
        target_age_band: { type: "integer", enum: [ 20, 30, 40, 50 ] },
        season: { type: "string", enum: %w[봄 여름 가을 겨울 간절기 사계절] },
        character_handle: { type: "string" }, alt_character_handle: { type: "string" },
        concept_angle: { type: "string", enum: %w[peer_fit motion_fit privacy other] },
        concept_title: { type: "string" }, hook_line: { type: "string" },
        attributes: { type: "object", additionalProperties: false,
          properties: { colors: { type: "array", items: { type: "string" } },
            silhouette: { type: [ "string", "null" ] },
            tpo: { type: "array", items: { type: "string" } },
            material_guess: { type: [ "string", "null" ] } },
          required: %w[colors silhouette tpo material_guess] },
        reasoning: { type: "string" }, confidence: { type: "number", description: "0~1 사이 확신도" }
      },
      required: %w[style_axis target_age_band season character_handle alt_character_handle concept_angle concept_title hook_line attributes reasoning confidence]
    }.freeze

    def initialize(analysis, client: nil)
      @analysis = analysis
      @client = client
    end

    def call
      return fail_analysis("ANTHROPIC_API_KEY 미설정 — 분석 불가") if ENV["ANTHROPIC_API_KEY"].blank?

      @analysis.update!(status: "running", error_message: nil)
      roster = Character.order(:id).to_a
      client = @client || Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])
      response = client.beta.messages.create(
        model: :"claude-opus-5-5", max_tokens: 4000,
        betas: [ "server-side-fallback-2026-07-01" ], fallbacks: "default",
        output_config: { effort: "medium", format: { type: "json_schema", schema: SCHEMA } },
        system: SYSTEM, messages: [ { role: "user", content: message_content(roster) } ]
      )
      return fail_analysis("분석 거절: #{response.stop_details&.category || '분류 없음'}") if response.stop_reason.to_s == "refusal"

      data = JSON.parse(response.content.find { |block| block.type.to_s == "text" }&.text.to_s)
      characters = roster.index_by(&:handle)
      primary = characters[data.fetch("character_handle")]
      alternate = characters[data.fetch("alt_character_handle")]
      return fail_analysis("로스터에 없는 캐릭터") unless primary && alternate
      confidence = data.fetch("confidence")
      return fail_analysis("확신도 범위 오류(0~1 밖)") unless confidence.is_a?(Numeric) && confidence.between?(0, 1)

      usage = response.usage
      input = usage.input_tokens.to_i
      output = usage.output_tokens.to_i
      @analysis.update!(status: "done", character: primary, alt_character: alternate,
        concept_angle: data.fetch("concept_angle"), concept_title: data.fetch("concept_title"),
        hook_line: data.fetch("hook_line"), season: data.fetch("season"),
        style_axis: data.fetch("style_axis"), target_age_band: data.fetch("target_age_band"),
        attributes_json: data.fetch("attributes").to_json, reasoning: data.fetch("reasoning"),
        confidence: confidence, model: response.model.to_s,
        input_tokens: input, output_tokens: output,
        cost_usd: (input * 4 + output * 20) / 1_000_000.0, analyzed_at: Time.current)
      Kpi::Calculator.new.assign_target!(@analysis)
      success(@analysis)
    rescue Anthropic::Errors::RateLimitError, Anthropic::Errors::APIStatusError,
      Anthropic::Errors::APIConnectionError => error
      Rails.logger.error("상품 분석 실패: #{error.class}: #{error.message}")
      fail_analysis("#{error.class}: #{error.message}")
    rescue JSON::ParserError, KeyError => error
      fail_analysis("분석 응답 오류: #{error.class}: #{error.message}")
    end

    private

    def fail_analysis(message)
      @analysis.update!(status: "failed", error_message: message)
      failure(message)
    end

    def message_content(roster)
      product = @analysis.product
      details = { name: product.name, category: product.category, brand: product.brand,
        price: product.price, supply_price: product.supply_price,
        material: product.parsed_ai_attributes["material"],
        colors: product.variants.map(&:color).uniq, sizes: product.variants.map(&:size).uniq,
        description: product.description }
      characters = roster.map do |character|
        { handle: character.handle, name: character.name, age: character.age,
          age_band: character.age_band, style_axis: character.style_axis,
          wardrobe: character.wardrobe, status: character.status }
      end
      content = [ { type: "text", text: { product: details, characters: characters }.to_json } ]
      if product.image.attached?
        jpeg = product.image.variant(resize_to_limit: [ 1024, 1024 ], format: :jpeg).processed.download
        content << { type: "image", source: { type: "base64", media_type: "image/jpeg", data: Base64.strict_encode64(jpeg) } }
      elsif product.image_url.to_s.match?(%r{\Ahttps?://})
        content << { type: "image", source: { type: "url", url: product.image_url } }
      end
      content
    end
  end
end
