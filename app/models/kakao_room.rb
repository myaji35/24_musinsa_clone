class KakaoRoom < ApplicationRecord
  include AccountScoped

  def alias_names
    aliases.to_s.lines.map(&:strip).reject(&:blank?).uniq
  end

  has_many :kakao_messages, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: { scope: :account_id }
end
