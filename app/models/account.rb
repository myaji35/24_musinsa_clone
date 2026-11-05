class Account < ApplicationRecord
  has_many :kakao_devices
  has_many :kakao_rooms
  has_many :kakao_messages
  has_many :users

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true

  def self.primary
    find_by!(slug: "jieum")
  end

  def self.primary_or_nil
    find_by(slug: "jieum")
  end
end
