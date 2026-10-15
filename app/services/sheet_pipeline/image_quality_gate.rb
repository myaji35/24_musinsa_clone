require "base64"
require "digest"
require "json"
require "net/http"
require "open3"
require "vips"

module SheetPipeline
  class ImageQualityGate
    MAX_BYTES = 20.megabytes
    MAX_REDIRECTS = 3
    TIMEOUT = 20
    MIN_SIDE = { reject: 512, pass: 800 }.freeze
    JPEG_QUALITY = { reject: 70, pass: 85 }.freeze
    SHARPNESS = { reject: 100, pass: 300 }.freeze
    CRUSHED = { pass: 5.0, reject: 15.0 }.freeze
    LAPLACIAN = Vips::Image.new_from_array([ [ 0, -1, 0 ], [ -1, 4, -1 ], [ 0, -1, 0 ] ], 1, 0)
    VERDICTS = %w[통과 보완 반려].freeze
    MODEL = :"claude-sonnet-5-5"
    CHECK_NAMES = %w[full_garment single_item occlusion shape color].freeze
    SCHEMA = {
      type: "object", additionalProperties: false,
      properties: {
        score: { type: "integer", minimum: 0, maximum: 100 },
        verdict: { type: "string", enum: VERDICTS },
        reason: { type: "string" },
        checks: { type: "object", additionalProperties: false,
          properties: CHECK_NAMES.to_h { |name| [ name.to_sym, { type: "string", enum: [ "ok", "bad", "확인 불가" ] } ] },
          required: CHECK_NAMES }
      }, required: %w[score verdict reason checks]
    }.freeze
    SYSTEM = <<~TEXT.freeze
      의류 상품 이미지의 내용 품질만 판정한다. 옷 전체가 보이지 않아 소매나 밑단이 잘렸거나,
      여러 벌이 섞여 상품이 모호하거나, 워터마크·텍스트·타사 로고가 옷을 가리거나,
      구겨져 실루엣을 알 수 없으면 반려한다. 강한 조명 색으로 실물 색 판단이 어려우면 보완한다.
      흰 날림 등 옷의 디테일 손실도 살펴 판정한다. 확인 불가한 것은 확인 불가로, 수치를 지어내지 말 것.
      점수는 0~100 정수, 사유는 한 줄로 답한다.
    TEXT

    def initialize(fetcher: nil, client: nil)
      @fetcher = fetcher || method(:download)
      @client = client
    end

    def call(row)
      url = row["이미지"].to_s.lines.first.to_s.strip
      bytes = @fetcher.call(url)
      raise "빈 파일" if bytes.nil? || bytes.empty?
      raise "20MB 초과" if bytes.bytesize > MAX_BYTES

      sha256 = Digest::SHA256.hexdigest(bytes)
      check = ImageQualityCheck.find_by(product_code: row.fetch("상품코드"), image_sha256: sha256)
      return result_for(check, row) if check

      image = Vips::Image.new_from_buffer(bytes, "")
      raise "이미지 아님" if image.width < 1 || image.height < 1

      metrics, findings = measure(image, bytes)
      verdict = worst(findings.map(&:first))
      score = nil
      vision_model = nil
      reason = findings.select { |level, _| level == verdict && level != "통과" }.first(2).map(&:last).join("; ")

      if verdict != "반려"
        begin
          vision = inspect_content(image)
          score = vision.fetch("score")
          vision_model = MODEL.to_s
          vision_verdict = vision.fetch("verdict")
          if VERDICTS.index(vision_verdict) > VERDICTS.index(verdict)
            verdict = vision_verdict
            reason = vision.fetch("reason")
          elsif vision_verdict == verdict && vision_verdict != "통과"
            reason = [ reason, vision.fetch("reason") ].reject(&:blank?).first(2).join("; ")
          end
        rescue StandardError => error
          Rails.logger.error("이미지 2차 내용 판정 미실행: #{error.class}: #{error.message}")
          verdict = "보완" if verdict == "통과"
          reason = [ reason.to_s.split("; ").first, "2차 내용 판정 미실행: #{short_error(error)}" ].reject(&:blank?).join("; ")
        end
      end

      reason = "수치·내용 기준 충족" if reason.blank?

      check = ImageQualityCheck.create!(product_code: row.fetch("상품코드"), image_url: url,
        image_sha256: sha256, verdict: verdict, score: score, reason: reason,
        metrics_json: metrics.to_json, vision_model: vision_model, checked_at: Time.current)
      result_for(check, row)
    rescue StandardError => error
      raise if error.is_a?(ActiveRecord::ActiveRecordError)

      Rails.logger.error("이미지 파일 판정 실패: #{error.class}: #{error.message}")
      reason = "파일 열리지 않음: #{short_error(error)}"
      check = ImageQualityCheck.where(product_code: row.fetch("상품코드"), image_url: url,
        image_sha256: nil, reason: reason).order(checked_at: :desc, id: :desc).first
      check ||= ImageQualityCheck.create!(product_code: row.fetch("상품코드"), image_url: url,
        verdict: "반려", reason: reason, metrics_json: {}.to_json, checked_at: Time.current)
      result_for(check, row)
    end

    private

    def result_for(check, row)
      metrics = JSON.parse(check.metrics_json.presence || "{}")
      result = { "이미지판정" => check.verdict, "판정점수" => check.score || "",
        "판정사유" => check.reason, "수치" => metrics.fetch("display", ""),
        "판정시각" => check.checked_at.iso8601 }
      if check.verdict == "반려"
        result["상태"] = "반려:#{check.reason.to_s[0, 80]}"
        result[:halt] = true
      elsif check.verdict == "보완" && row["MD확인"] != "진행"
        result["상태"] = "MD확인 대기"
        result[:halt] = true
      elsif row["상태"].to_s.start_with?("반려:") || row["상태"] == "MD확인 대기"
        result["상태"] = "대기"
      end
      result
    end

    def worst(verdicts)
      verdicts.max_by { |verdict| VERDICTS.index(verdict) } || "통과"
    end

    def measure(image, bytes)
      side = [ image.width, image.height ].min
      quality = jpeg?(bytes) ? jpeg_quality(bytes) : nil
      gray = image.colourspace(:b_w).cast(:uchar)
      clothing_mask = gray < 245
      clothing_fraction = clothing_mask.avg / 255.0
      display = [ "#{side}px", quality ? "Q#{quality}" : "Q-" ]
      findings = []
      findings << [ side < MIN_SIDE[:reject] ? "반려" : side < MIN_SIDE[:pass] ? "보완" : "통과",
        "짧은 변 #{side}px, #{MIN_SIDE[:pass]}px 이상 필요" ]
      if quality
        findings << [ quality < JPEG_QUALITY[:reject] ? "반려" : quality < JPEG_QUALITY[:pass] ? "보완" : "통과",
          "JPEG 품질 Q#{quality}, Q#{JPEG_QUALITY[:pass]} 이상 필요" ]
      end

      if clothing_fraction < 0.01
        display.concat([ "선명 측정 불가", "뭉개짐 측정 불가" ])
        findings << [ "보완", "옷 영역 1% 미만으로 선명도·뭉개짐 측정 불가" ]
      else
        sharpness = laplacian_variance(gray, clothing_mask, clothing_fraction)
        crushed = (gray <= 5).avg / 255.0 * 100.0 / clothing_fraction
        display.concat([ "선명 #{sharpness.round}", "뭉개짐 #{format('%.1f', crushed)}%" ])
        findings << [ sharpness < SHARPNESS[:reject] ? "반려" : sharpness < SHARPNESS[:pass] ? "보완" : "통과",
          "선명 #{sharpness.round}, #{SHARPNESS[:pass]} 이상 필요" ]
        findings << [ crushed > CRUSHED[:reject] ? "반려" : crushed >= CRUSHED[:pass] ? "보완" : "통과",
          "뭉개짐 #{format('%.1f', crushed)}%, #{CRUSHED[:pass]}% 미만 필요" ]
      end
      [ { display: display.join(" · "), short_side: side, jpeg_quality: quality }, findings ]
    end

    def laplacian_variance(gray, clothing_mask, clothing_fraction)
      laplacian = gray.cast(:float).conv(LAPLACIAN)
      mean = clothing_mask.ifthenelse(laplacian, 0).avg / clothing_fraction
      mean_squares = clothing_mask.ifthenelse(laplacian * laplacian, 0).avg / clothing_fraction
      mean_squares - mean**2
    end

    def jpeg?(bytes)
      bytes.start_with?("\xFF\xD8".b)
    end

    def jpeg_quality(bytes)
      output, error, status = Open3.capture3("identify", "-format", "%Q", "-", stdin_data: bytes, binmode: true)
      raise "JPEG 품질 확인 실패: #{error.to_s[0, 80]}" unless status.success?

      Integer(output)
    end

    def inspect_content(image)
      raise "ANTHROPIC_API_KEY 미설정" if @client.nil? && ENV["ANTHROPIC_API_KEY"].blank?

      ratio = [ 1568.0 / [ image.width, image.height ].max, 1.0 ].min
      scaled = ratio < 1 ? image.resize(ratio) : image
      scaled = scaled.flatten(background: [ 255, 255, 255 ]) if scaled.has_alpha?
      jpeg = scaled.write_to_buffer(".jpg")
      content = [ { type: "text", text: "의류 이미지 내용 품질을 판정하세요." },
        { type: "image", source: { type: "base64", media_type: "image/jpeg", data: Base64.strict_encode64(jpeg) } } ]
      client = @client || Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
      response = client.beta.messages.create(model: MODEL, max_tokens: 1000,
        output_config: { format: { type: "json_schema", schema: SCHEMA } },
        system: SYSTEM, messages: [ { role: "user", content: content } ])
      raise "응답 거절" if response.stop_reason.to_s == "refusal"

      data = JSON.parse(response.content.find { |block| block.type.to_s == "text" }&.text.to_s)
      raise "점수 범위 오류" unless data["score"].is_a?(Integer) && data["score"].between?(0, 100)
      raise "판정 오류" unless VERDICTS.include?(data["verdict"])
      raise "사유 누락" unless data["reason"].is_a?(String)
      raise "체크 누락" unless CHECK_NAMES.all? { |name| %w[ok bad 확인 불가].include?(data.fetch("checks", {})[name]) }

      data
    end

    def download(url, redirects = 0)
      uri = URI.parse(url)
      raise "HTTP URL 아님" unless %w[http https].include?(uri.scheme)
      raise "리다이렉트 초과" if redirects > MAX_REDIRECTS

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(uri.request_uri)) do |response|
          if response.is_a?(Net::HTTPRedirection)
            return download(URI.join(uri.to_s, response["location"]).to_s, redirects + 1)
          end
          raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          body = +"".b
          response.read_body do |chunk|
            body << chunk
            raise "20MB 초과" if body.bytesize > MAX_BYTES
          end
          return body
        end
      end
    end

    def short_error(error)
      error.message.to_s.gsub(/\s+/, " ")[0, 80]
    end
  end
end
