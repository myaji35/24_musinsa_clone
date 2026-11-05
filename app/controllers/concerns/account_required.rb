module AccountRequired
  extend ActiveSupport::Concern

  private

  def require_account_member
    redirect_to login_path, alert: "계정 로그인이 필요합니다." unless logged_in? && current_account
  end

  # 계정 소속 레코드는 current_account.<assoc>.find(params[:id])로 조회한다.
end
