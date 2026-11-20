class AccessLog < ApplicationRecord
  scope :expired, -> { where("created_at < ?", Rails.configuration.x.access_log_retention_days.days.ago) }

  def self.mask_email(email)
    local, domain = email.to_s.split("@", 2)
    "#{local.to_s.first}***@#{domain}"
  end
end
