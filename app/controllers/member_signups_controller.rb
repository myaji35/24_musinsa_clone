class MemberSignupsController < ApplicationController
  skip_before_action :require_admin
  before_action :redirect_logged_in_user
  rate_limit to: 10, within: 3.minutes, only: :create

  def new
    @user = User.new
  end

  def create
    attributes = member_params
    @consents = attributes.extract!(:terms_agreement, :privacy_agreement, :age_confirmation)
    @user = User.new(attributes)
    @user.role = :member
    @user.account = nil

    @user.valid?
    @user.errors.add(:name, "을 입력해 주세요.") if @user.name.blank?
    {
      terms_agreement: "이용약관에 동의해 주세요.",
      privacy_agreement: "개인정보 수집·이용에 동의해 주세요.",
      age_confirmation: "만 14세 이상만 가입할 수 있습니다."
    }.each do |key, message|
      @user.errors.add(:base, message) unless @consents[key] == "1"
    end

    if @user.errors.any?
      render :new, status: :unprocessable_entity
      return
    end

    agreed_at = Time.current
    @user.assign_attributes(terms_agreed_at: agreed_at, privacy_agreed_at: agreed_at, age_confirmed_at: agreed_at)
    if @user.save
      reset_session
      session[:user_id] = @user.id
      redirect_to root_path, notice: "회원가입이 완료되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def redirect_logged_in_user
    redirect_to root_path, notice: "이미 로그인되어 있습니다." if logged_in?
  end

  def member_params
    params.require(:member).permit(:name, :email, :password, :password_confirmation,
      :terms_agreement, :privacy_agreement, :age_confirmation)
  end
end
