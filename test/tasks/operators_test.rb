require "test_helper"
require "rake"

class OperatorsTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("operators:create")
    @environment = ENV.to_h.slice("EMAIL", "NAME", "TEMP_PASSWORD", "ACCOUNT_SLUG")
    ENV["EMAIL"] = "operator@example.com"
    ENV["NAME"] = "운영자"
    ENV["TEMP_PASSWORD"] = "tiny"
    ENV.delete("ACCOUNT_SLUG")
  end

  teardown do
    %w[EMAIL NAME TEMP_PASSWORD ACCOUNT_SLUG].each { |key| ENV.delete(key) }
    @environment.each { |key, value| ENV[key] = value }
  end

  test "생성과 재설정은 짧은 임시 비밀번호를 허용하고 출력하지 않는다" do
    assert_difference "User.count", 1 do
      run_task
    end
    user = User.find_by!(email: ENV["EMAIL"])
    assert_equal Account.primary, user.account
    assert user.must_change_password?
    assert user.authenticate("tiny")
    user.update!(must_change_password: false, password_changed_at: Time.current)
    ENV["NAME"] = "변경 운영자"
    ENV["TEMP_PASSWORD"] = "reset-secret"
    ENV["ACCOUNT_SLUG"] = accounts(:other).slug
    assert_no_difference "User.count" do
      run_task
    end
    assert_equal "변경 운영자", user.reload.name
    assert_equal accounts(:other), user.account
    assert user.must_change_password?
    assert_nil user.password_changed_at
    assert user.authenticate("reset-secret")
    assert_not user.authenticate("tiny")
  end

  test "필수 환경 변수가 없으면 비밀번호를 출력하지 않고 종료한다" do
    %w[EMAIL NAME TEMP_PASSWORD].each do |key|
      original = ENV.delete(key)
      _out, err = capture_io do
        assert_raises(SystemExit) { invoke_task }
      end
      assert_includes err, key
      assert_not_includes err, "tiny"
      ENV[key] = original
    end
  end

  private

  def invoke_task
    Rake::Task["operators:create"].reenable
    Rake::Task["operators:create"].invoke
  end

  def run_task
    out, err = capture_io { invoke_task }
    assert_includes out, ENV["EMAIL"]
    assert_includes out, ENV.fetch("ACCOUNT_SLUG", "jieum")
    assert_not_includes out + err, ENV["TEMP_PASSWORD"]
    assert_not_includes out, ENV["NAME"]
  end
end
