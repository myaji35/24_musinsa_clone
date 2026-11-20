class User < ApplicationRecord
  belongs_to :account, optional: true
  has_many :orders, dependent: :nullify
  has_many :reviews, dependent: :destroy
  has_many :snaps, dependent: :destroy

  has_secure_password

  enum :role, { member: 0, operator: 1, admin: 2 }, default: :member, validate: true

  scope :search, ->(q) { q.present? ? where("users.name LIKE :q ESCAPE '\\' OR users.email LIKE :q ESCAPE '\\'", q: "%#{User.sanitize_sql_like(q.strip)}%") : all }

  def suspended? = suspended_at.present?

  validates :password, length: { minimum: 8 }, allow_nil: true

  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  def withdraw!(reason: nil)
    raise ArgumentError, "일반 회원만 탈퇴할 수 있습니다." unless member?

    transaction do
      MemberWithdrawal.create!(withdrawn_at: Time.current, orders_count: orders.count, reason: reason.presence)
      destroy!
    end
  end

  def role_label
    { "member" => "일반 회원", "operator" => "운영자", "admin" => "관리자" }[role]
  end

  def staff?
    admin? || operator?
  end
end
