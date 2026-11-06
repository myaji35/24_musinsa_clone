class AccountSignupsController < ApplicationController
  skip_before_action :require_admin
  before_action :require_signup_enabled

  def new
    @account = Account.new
    @user = User.new
  end

  def create
    @account = Account.new(name: signup_params[:account_name])
    base = @account.name.to_s.parameterize.presence || "account"
    @account.slug = base
    suffix = 2
    while Account.exists?(slug: @account.slug)
      @account.slug = "#{base}-#{suffix}"
      suffix += 1
    end
    @user = @account.users.build(signup_params.except(:account_name))
    if @user.name.blank? || signup_params[:password_confirmation].blank?
      @user.errors.add(:base, "이름과 비밀번호 확인을 입력해 주세요.")
      render :new, status: :unprocessable_entity
      return
    end
    Account.transaction do
      @account.save!
      @user.save!
    end
    reset_session
    session[:user_id] = @user.id
    redirect_to workspace_path, notice: "가입이 완료되었습니다."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    @account.errors.add(:base, "가입 정보를 확인해 주세요.")
    render :new, status: :unprocessable_entity
  end

  private

  def signup_params
    params.require(:signup).permit(:account_name, :name, :email, :password, :password_confirmation)
  end

  def require_signup_enabled
    head :not_found unless %w[1 true].include?(ENV["SAAS_SIGNUP_ENABLED"])
  end
end
