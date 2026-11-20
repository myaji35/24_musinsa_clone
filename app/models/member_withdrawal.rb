class MemberWithdrawal < ApplicationRecord
  REASONS = {
    "not_used" => "자주 이용하지 않음",
    "no_products" => "원하는 상품이 없음",
    "privacy" => "개인정보 걱정",
    "service" => "서비스 불만",
    "other" => "기타"
  }.freeze

  validates :reason, inclusion: { in: REASONS.keys }, allow_nil: true
end
