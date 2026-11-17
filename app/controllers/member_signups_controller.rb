class MemberSignupsController < ApplicationController
  skip_before_action :require_admin
  before_action :redirect_logged_in_user
  rate_limit to: 10, within: 3.minutes, only: :create

  def new
    @user = User.new
  end

  def create
    @user = User.new(member_params)
    @user.role = :member
    @user.account = nil

    if @user.name.blank?
      @user.valid?
      @user.errors.add(:name, "을 입력해 주세요.")
      render :new, status: :unprocessable_entity
    elsif @user.save
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
    params.require(:member).permit(:name, :email, :password, :password_confirmation)
  end
end
