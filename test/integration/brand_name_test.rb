require "test_helper"

# ISS-159: 브랜드 표기는 JIEUM 으로 확정(2026-10-31 대표님 결정).
# app/ 아래에 이전 표기 JIEUN 이 다시 들어오지 않게 막는다.
# 환경변수명(JIEUN_SHEET_*)은 운영 설정 연쇄 때문에 예외로 둔다.
class BrandNameTest < ActiveSupport::TestCase
  ALLOWED = /JIEUN_SHEET_(ID|TAB)/

  test "app/ 에 이전 브랜드 표기 JIEUN 이 없다" do
    offenders = Dir[Rails.root.join("app/**/*.{rb,erb}")].flat_map do |path|
      File.readlines(path, encoding: "UTF-8").each_with_index.filter_map do |line, idx|
        next unless line.gsub(ALLOWED, "").match?(/JIEUN|Jieun/)

        "#{path.sub("#{Rails.root}/", "")}:#{idx + 1}"
      end
    end

    assert_empty offenders, "JIEUN 표기가 남아 있습니다: #{offenders.join(', ')}"
  end

  test "파트너센터·메일 제목·슬랙 봇 이름이 JIEUM 이다" do
    assert_includes File.read(Rails.root.join("app/views/layouts/partner.html.erb")), "JIEUM 파트너센터"
    assert_includes File.read(Rails.root.join("app/mailers/notification_mailer.rb")), "[JIEUM]"
    notifier = Notifications::SlackNotifier.new(channel: "#ops", text: "확인")
    assert_equal "JIEUM Bot", notifier.instance_variable_get(:@username)
  end
end
