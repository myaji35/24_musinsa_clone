module Admin
  class UsersController < ApplicationController
    def index
      @users = User.includes(:account).order(:created_at)
    end

    def update
      user = User.find(params[:id])
      role = params.require(:user).permit(:role)[:role]

      if user == current_user
        redirect_to admin_users_path, alert: "본인 역할은 변경할 수 없습니다."
        return
      end
      unless User.roles.key?(role)
        redirect_to admin_users_path, alert: "올바른 역할을 선택해 주세요."
        return
      end

      # 관리자 행을 같은 순서로 잠가 동시 강등 요청도 직렬화한다.
      User.transaction do
        admins = User.where(role: :admin).order(:id).lock.to_a
        user.lock!
        if user.admin? && role != "admin" && admins.size <= 1
          redirect_to admin_users_path, alert: "관리자가 최소 1명 필요합니다."
        elsif user.update(role: role)
          redirect_to admin_users_path, notice: "역할을 변경했습니다."
        else
          redirect_to admin_users_path, alert: user.errors.full_messages.to_sentence
        end
      end
    end
  end
end
