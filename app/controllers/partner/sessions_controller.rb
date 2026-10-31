module Partner
  class SessionsController < BaseController
    skip_before_action :require_supplier_account
    rate_limit to: 10, within: 3.minutes, only: :create

    def new
    end

    def create
      account = SupplierAccount.find_by(email: params[:email].to_s.strip.downcase)
      if account&.active? && account.supplier.active? && account.authenticate(params[:password].to_s)
        reset_session
        session[:supplier_account_id] = account.id
        account.update!(last_sign_in_at: Time.current)
        redirect_to partner_root_path, notice: "로그인되었습니다."
      else
        flash.now[:alert] = "이메일 또는 비밀번호가 올바르지 않습니다."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      reset_session
      redirect_to partner_login_path, status: :see_other
    end
  end
end
