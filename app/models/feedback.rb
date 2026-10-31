class Feedback < ApplicationRecord
  encrypts :contact_email
  serialize :factory_flags, coder: JSON, type: Array

  belongs_to :product, optional: true

  before_validation :normalize_input

  validates :body, length: { minimum: 10, maximum: 2000,
                            too_short: "의견은 10자 이상 적어 주세요",
                            too_long: "의견은 2000자 이하로 적어 주세요" }
  validates :kind, inclusion: { in: %w[bug idea praise other] }
  validates :status, inclusion: { in: %w[new in_review answered closed needs_review forwarded] }
  validates :source, inclusion: { in: %w[customer_web partner admin_note kakao_manual] }
  validates :page_url, length: { maximum: 500 }
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "이메일 형식을 확인해 주세요" }, allow_blank: true

  scope :contact_purgeable, -> {
    where.not(contact_email: nil).where(contact_purged_at: nil)
      .where("created_at < ? OR status IN (?)", 90.days.ago, %w[answered closed])
  }

  private

  def normalize_input
    self.body = body.to_s.strip
    self.contact_email = nil unless contact_consent?
    self.contact_email = nil if contact_email.blank?
  end
end
