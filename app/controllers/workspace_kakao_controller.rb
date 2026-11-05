class WorkspaceKakaoController < ApplicationController
  skip_before_action :require_admin
  before_action :require_account_member

  def index
    @devices = current_account.kakao_devices.order(:id)
    @rooms = current_account.kakao_rooms.order(:name)
    @messages = current_account.kakao_messages.includes(:kakao_room).order(created_at: :desc, id: :desc).limit(50)
  end

  def create_device
    @device, @token = KakaoDevice.issue!(account: current_account, name: params[:name])
    response.headers["Cache-Control"] = "no-store"
    render :connected
  rescue ActiveRecord::RecordInvalid => e
    redirect_to workspace_kakao_path, alert: e.record.errors.full_messages.join(", ")
  end

  def update_device
    device = current_account.kakao_devices.find(params[:id])
    device.update!(params.require(:device).permit(:collect_start_hour, :collect_end_hour, :max_rooms_per_run, :allow_focus))
    redirect_to workspace_kakao_path, notice: "기기 설정을 저장했습니다"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to workspace_kakao_path, alert: e.record.errors.full_messages.join(", ")
  end

  def revoke_device
    current_account.kakao_devices.find(params[:id]).update!(revoked_at: Time.current)
    redirect_to workspace_kakao_path, notice: "기기를 폐기했습니다"
  end

  def create_room
    current_account.kakao_rooms.create!(params.permit(:name))
    redirect_to workspace_kakao_path, notice: "방을 추가했습니다"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to workspace_kakao_path, alert: e.record.errors.full_messages.join(", ")
  end

  def update_room
    current_account.kakao_rooms.find(params[:id]).update!(active: params[:active] == "true")
    redirect_to workspace_kakao_path
  end

  def destroy_room
    room = current_account.kakao_rooms.find(params[:id])
    if room.kakao_messages.exists?
      room.update!(active: false)
      redirect_to workspace_kakao_path, notice: "메시지가 있어 삭제 대신 비활성화했습니다"
    else
      room.destroy!
      redirect_to workspace_kakao_path, notice: "방을 삭제했습니다"
    end
  end
end
