# Epic 6.1: 마케팅 캠페인 모델
# Claude AI로 개인화된 마케팅 메시지 생성 및 발송 관리
class Campaign < ApplicationRecord
  belongs_to :product, optional: true

  # JSONB 직렬화
  serialize :target_segment, coder: JSON

  # Validations
  validates :name, presence: true
  validates :campaign_type, presence: true, inclusion: { in: %w[new_arrival restock personalized seasonal] }
  validates :status, inclusion: { in: %w[draft scheduled sent cancelled] }

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
    target_customers = find_target_customers
    update(target_count: target_customers.count)

    sent = 0
    target_customers.find_each do |customer|
      # 개인화 메시지 생성
      personalized_message = generate_personalized_message(customer)

      # Notification 레코드 생성
      Notification.create!(
        notification_type: "campaign",
        message: personalized_message,
        status: "sent"
      )

      # Slack 알림 (내부 모니터링용)
      if sent < 5 # 처음 5명만 Slack 알림
        Notifications::SlackNotifier.call(
          channel: "#marketing",
          text: "📢 캠페인 발송: #{name} - #{customer.uuid.first(8)}... (#{sent + 1}/#{target_customers.count})"
        )
      end

      sent += 1
    end

    update(status: "sent", sent_at: Time.current, sent_count: sent)
    Rails.logger.info "✅ 캠페인 발송 완료: #{name} (#{sent}명)"
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
      )
    else
      # 기본 메시지
      "안녕하세요! 고객님을 위한 특별한 상품을 준비했습니다."
    end
  end
end
