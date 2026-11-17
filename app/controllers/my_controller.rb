class MyController < ApplicationController
  skip_before_action :require_admin
  before_action :require_login
  rate_limit to: 10, within: 3.minutes, only: :update_password

  def show
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    @user.assign_attributes(params.require(:user).permit(:name))
    if @user.name.blank?
      @user.errors.add(:base, "이름을 입력해 주세요.")
      render :edit, status: :unprocessable_entity
    elsif @user.save
      redirect_to my_path, notice: "내 정보를 수정했습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def edit_password
    @user = current_user
  end

  def update_password
    password_change = params.require(:password_change).permit(:current_password, :password, :password_confirmation)
    @user = current_user

    if !@user.authenticate(password_change[:current_password].to_s)
      @user.errors.add(:base, "현재 비밀번호가 올바르지 않습니다.")
    elsif password_change[:password].blank?
      @user.errors.add(:base, "새 비밀번호를 입력해 주세요.")
    elsif @user.authenticate(password_change[:password].to_s)
      @user.errors.add(:base, "현재와 다른 비밀번호를 입력해 주세요.")
    elsif @user.update(password: password_change[:password], password_confirmation: password_change[:password_confirmation])
      user_id = @user.id
      reset_session
      session[:user_id] = user_id
      redirect_to my_path, notice: "비밀번호를 변경했습니다."
      return
    end

    render :edit_password, status: :unprocessable_entity
  end

  def orders
    @orders = current_user.orders.includes(:product, :variant).order(created_at: :desc)
  end
end
