# Epic 6.1: 마케팅 캠페인 모델
# Claude AI로 개인화된 마케팅 메시지 생성 및 발송 관리
class Campaign < ApplicationRecord
  belongs_to :product, optional: true
  has_many :campaign_deliveries, dependent: :destroy

  # JSONB 직렬화
  serialize :target_segment, coder: JSON

  # Validations
  validates :name, presence: true
  validates :campaign_type, presence: true, inclusion: { in: %w[new_arrival restock personalized seasonal] }
  validates :status, inclusion: { in: %w[draft scheduled sent cancelled failed partially_failed] }

  # Scopes
  scope :draft, -> { where(status: "draft") }
  scope :scheduled, -> { where(status: "scheduled") }
  scope :sent, -> { where(status: "sent") }
  scope :pending_send, -> { where(status: "scheduled").where("scheduled_at <= ?", Time.current) }

  # Methods

  # 타겟 고객 찾기
  def find_target_customers
    customers = AnonyCustomer.all

    return customers unless target_segment.present?

    # 세그먼트 조건 필터링
    if target_segment["zip_prefix"].present?
      customers = customers.where(zip_prefix: target_segment["zip_prefix"])
    end

    if target_segment["age_group"].present?
      current_year = Date.today.year
      age_range = case target_segment["age_group"]
      when "10대" then (current_year - 19)..(current_year - 10)
      when "20대" then (current_year - 29)..(current_year - 20)
      when "30대" then (current_year - 39)..(current_year - 30)
      when "40대" then (current_year - 49)..(current_year - 40)
      else (0)..(current_year - 50)
      end

      customers = customers.where(birth_year: age_range)
    end

    # 취향 태그 필터링
    if target_segment["preferences"].present?
      target_segment["preferences"].each do |pref|
        customers = customers.where("preference_tags LIKE ?", "%#{pref}%")
      end
    end

    customers
  end

  # 캠페인 발송
  def send_campaign!
    # 메시지 생성(외부 API 호출 가능)을 트랜잭션 밖에서 고객 단위로 처리한다.
    # 고객당 이력은 (campaign_id, anony_customer_id) unique 인덱스로 한 건만 남는다.
    sent = 0
    failed = 0
    find_target_customers.find_each do |customer|
      delivery = campaign_deliveries.find_or_create_by!(anony_customer: customer)
      if delivery.status == "sent"
        sent += 1
        next
      end

      begin
        message = generate_personalized_message(customer)
      rescue StandardError => e
        delivery.update!(status: "failed", failure_reason: "#{e.class}: #{e.message}".truncate(500), sent_at: nil)
        failed += 1
        next
      end

      delivery.update!(status: "sent", message: message, failure_reason: nil, sent_at: Time.current)
      sent += 1
    end

    total = sent + failed
    result = if total.zero? || sent.zero?
      "failed"
    elsif failed.positive?
      "partially_failed"
    else
      "sent"
    end
    reason = if total.zero?
      "발송 대상 고객이 없습니다."
    elsif failed.positive?
      "#{total}명 중 #{failed}명 발송 실패 — 고객별 사유는 발송 이력(campaign_deliveries) 참조"
    end
    update!(status: result, target_count: total, sent_count: sent,
            sent_at: sent.positive? ? Time.current : nil, failure_reason: reason)

    notify_delivery_summary
  end

  def notify_delivery_summary
    Notifications::SlackNotifier.call(
      channel: "#marketing",
      text: "📢 캠페인 발송 완료: #{name} - #{status} (#{sent_count}/#{target_count}명)"
    )
  rescue StandardError => e
    Rails.logger.warn "캠페인 Slack 요약 실패: #{e.class}: #{e.message}"
  end

  # 개인화 메시지 생성
  def generate_personalized_message(customer)
    if message_template.present?
      # 템플릿이 있으면 사용
      message_template
    elsif product.present?
      # 상품이 있으면 Claude AI로 생성
      ClaudeBot::MessageGenerator.generate_marketing_message(
        customer.preference_tags || {},
        product
      )[:text]
    else
      # 기본 메시지
      "안녕하세요! 고객님을 위한 특별한 상품을 준비했습니다."
    end
  end
end
