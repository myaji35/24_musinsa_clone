class User < ApplicationRecord
  belongs_to :account, optional: true

  has_secure_password

  enum :role, { member: 0, operator: 1, admin: 2 }, default: :member, validate: true

  validates :password, length: { minimum: 8 }, allow_nil: true

  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  def role_label
    { "member" => "일반 회원", "operator" => "운영자", "admin" => "관리자" }[role]
  end

  def staff?
    admin? || operator?
  end
end
