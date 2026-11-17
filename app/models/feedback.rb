class Feedback < ApplicationRecord
  include AccountScoped

  CONTACT_RETENTION_DAYS = 90

  KINDS = { "막힘·헷갈림" => "stuck", "개선 아이디어" => "idea", "오류 신고" => "bug", "기타" => "other" }.freeze
  STATUSES = { "새 의견" => "new", "확인 중" => "in_review", "반영함" => "answered", "닫음" => "closed" }.freeze
  SOURCES = { "운영자" => [ "operator", "admin_note" ], "고객" => [ "customer_web", "kakao_manual" ], "파트너" => [ "partner" ] }.freeze
  MANUAL_CHAPTERS = {
    "0장 이 매뉴얼 쓰는 법" => 0,
    "1장 시작하기 — 로그인과 운영자 메뉴" => 1,
    "2장 OEM 공장을 거래처로 등록하기" => 2,
    "3장 공장 위챗 담당자 연결하기" => 3,
    "4장 발주서 만들고 제출하기" => 4,
    "5장 위챗으로 발주 통보 보내기 (복사해서 보내기)" => 5,
    "6장 공장 답장 확인하고 기록하기" => 6,
    "7장 공장 확정과 입고 처리" => 7,
    "8장 손님 주문 — 입금 확인과 결제 완료" => 8,
    "9장 판매현황과 재고" => 9,
    "10장 공장 클레임" => 10,
    "11장 문제가 생겼을 때" => 11
  }.freeze

  encrypts :contact_email
  serialize :factory_flags, coder: JSON, type: Array

  belongs_to :user, optional: true
  belongs_to :product, optional: true

  before_validation :normalize_input

  validates :body, length: { minimum: ->(feedback) { feedback.source == "operator" ? 5 : 10 }, maximum: 2000,
                            too_short: "의견은 %{count}자 이상 적어 주세요",
                            too_long: "의견은 2000자 이하로 적어 주세요" }
  validates :kind, inclusion: { in: %w[stuck bug idea praise other] }
  validates :status, inclusion: { in: %w[new in_review answered closed needs_review forwarded] }
  validates :source, inclusion: { in: %w[customer_web partner admin_note kakao_manual operator] }
  validates :manual_chapter, inclusion: { in: 0..11 }, allow_nil: true
  validates :page_url, length: { maximum: 500 }
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "이메일 형식을 확인해 주세요" }, allow_blank: true

  scope :contact_purgeable, -> {
    where.not(contact_email: nil).where(contact_purged_at: nil)
      .where("created_at < ? OR status IN (?)", CONTACT_RETENTION_DAYS.days.ago, %w[answered closed])
  }

  private

  def normalize_input
    self.account ||= Current.account || Account.primary
    self.body = body.to_s.strip
    self.contact_email = nil unless contact_consent?
    self.contact_email = nil if contact_email.blank?
  end
end
