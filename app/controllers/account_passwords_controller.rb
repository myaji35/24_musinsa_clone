class AccountPasswordsController < ApplicationController
  skip_before_action :require_admin
  before_action :require_login

  def edit
    @errors = []
  end

  def update
    password = params[:password].to_s
    @errors = []
    @errors << "현재 비밀번호가 올바르지 않습니다" unless current_user.authenticate(params[:current_password].to_s)
    @errors << "새 비밀번호는 8자 이상이어야 합니다" if password.length < 8
    @errors << "새 비밀번호는 현재 비밀번호와 달라야 합니다" if current_user.authenticate(password)
    @errors << "새 비밀번호 확인이 일치하지 않습니다" unless password == params[:password_confirmation].to_s
    weak_passwords = %w[123456 12345678 123456789 password password123 qwerty qwerty123 abcdefgh 11111111 00000000]
    weak_passwords << current_user.email.split("@").first.downcase
    @errors << "너무 쉬운 비밀번호는 사용할 수 없습니다" if weak_passwords.include?(password.downcase)
    @errors << "새 비밀번호는 72바이트 이하여야 합니다" if password.bytesize > 72

    if @errors.any?
      render :edit, status: :unprocessable_entity
      return
    end

    current_user.update!(password: password, password_confirmation: params[:password_confirmation],
                         must_change_password: false, password_changed_at: Time.current)
    destination = mall_admin? ? (session[:return_to].presence || purchase_orders_path) : account_password_path
    user_id = current_user.id
    reset_session
    session[:user_id] = user_id
    redirect_to destination, notice: "비밀번호를 바꿨습니다."
  end

  private

  def require_login
    redirect_to login_path, alert: "로그인이 필요합니다" unless logged_in?
  end
end
