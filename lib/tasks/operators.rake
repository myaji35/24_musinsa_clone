namespace :operators do
  desc "운영자 생성 또는 임시 비밀번호 재설정 (EMAIL, NAME, TEMP_PASSWORD, ACCOUNT_SLUG)"
  task create: :environment do
    email, name, password = %w[EMAIL NAME TEMP_PASSWORD].map do |key|
      ENV[key].presence || abort("#{key} 환경 변수가 필요합니다")
    end
    account = Account.find_by!(slug: ENV.fetch("ACCOUNT_SLUG", "jieum"))
    user = User.find_or_initialize_by(email: email.strip.downcase)
    # 임시 비밀번호는 첫 로그인 때 강제 변경하므로 여기서는 8자 미만도 허용한다.
    user.update!(name: name, account: account, password: password, password_confirmation: password,
                 must_change_password: true, password_changed_at: nil)
    puts "이메일: #{user.email}, 계정: #{account.slug}"
  end
end
