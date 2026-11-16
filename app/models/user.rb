class User < ApplicationRecord
  belongs_to :account, optional: true

  has_secure_password

  enum :role, { member: 0, operator: 1, admin: 2 }, default: :member, validate: true

  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  def staff?
    admin? || operator?
  end
end
