module PersonalDataAccessLogging
  extend ActiveSupport::Concern

  included do
    protected

    def log_personal_data_access(screen:, target: nil)
      return unless mall_staff?

      AccessLog.create!(user_id: current_user.id,
        user_label: "#{current_user.role} #{AccessLog.mask_email(current_user.email)}",
        screen: screen, action: action_name, target_type: target&.class&.name,
        target_id: target&.id, ip: request.remote_ip)
    rescue StandardError => error
      Rails.logger.error("개인정보 접속기록 실패: #{error.class}")
    end
  end
end
