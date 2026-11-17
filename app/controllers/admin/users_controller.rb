module Admin
  class UsersController < ApplicationController
    include PersonalDataAccessLogging
    def index
      q = params[:q]
      role = params[:role]
      status = params[:status]
      users = User.search(q)
      users = users.where(role: role) if User.roles.key?(role)
      users = users.where.not(suspended_at: nil) if status == "suspended"
      users = users.where(suspended_at: nil) if status == "active"
      @total_count = users.count
      @page = params[:page].to_i.clamp(1, Float::INFINITY)
      @total_pages = (@total_count / 20.0).ceil
      @users = users.includes(:account).order(created_at: :desc).offset((@page - 1) * 20).limit(20)
      log_personal_data_access(screen: "사용자 관리")
    end

    def suspend
      user = User.find(params[:id])
      if user == current_user
        redirect_to admin_users_path(list_params), alert: "본인 계정은 정지할 수 없습니다."
      elsif user.admin?
        redirect_to admin_users_path(list_params), alert: "관리자 계정은 먼저 역할을 바꾼 뒤 정지해 주세요."
      else
        user.update!(suspended_at: Time.current)
        redirect_to admin_users_path(list_params), notice: "계정을 정지했습니다."
      end
    end

    def unsuspend
      User.find(params[:id]).update!(suspended_at: nil)
      redirect_to admin_users_path(list_params), notice: "계정 정지를 해제했습니다."
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

    private

    def list_params
      params.permit(:q, :role, :status, :page).to_h
    end
  end
end
