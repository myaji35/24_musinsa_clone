class KakaoRoom < ApplicationRecord
  include AccountScoped

  has_many :kakao_messages, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: { scope: :account_id }
end
