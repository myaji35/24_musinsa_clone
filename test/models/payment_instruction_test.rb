require "test_helper"

class PaymentInstructionTest < ActiveSupport::TestCase
  test "입금 기한은 미설정 빈 값 숫자가 아닌 값이면 3일이다" do
    [ nil, "", "  ", "abc", "3.5", "-1" ].each do |value|
      with_payout_env("PAYOUT_DUE_DAYS" => value) do
        assert_equal 3, PaymentInstruction.new.due_days
      end
    end
    with_payout_env("PAYOUT_DUE_DAYS" => " 5 ") do
      assert_equal 5, PaymentInstruction.new.due_days
    end
  end

  test "은행 계좌 예금주는 공백을 제거하고 하나라도 비면 준비되지 않는다" do
    values = { "PAYOUT_BANK" => " 테스트은행 ", "PAYOUT_ACCOUNT" => " 000-00-000000 ", "PAYOUT_HOLDER" => " 테스트예금주 " }
    with_payout_env(values) do
      instruction = PaymentInstruction.new
      assert instruction.ready?
      assert_equal "테스트은행", instruction.bank
      assert_equal "000-00-000000", instruction.account
      assert_equal "테스트예금주", instruction.holder
      assert_equal "", instruction.contact
    end
    values.each_key do |key|
      with_payout_env(values.merge(key => " \t ")) { assert_not PaymentInstruction.new.ready? }
      with_payout_env(values.except(key)) { assert_not PaymentInstruction.new.ready? }
    end
  end

  test "입금 기한은 서버 시간대와 무관하게 서울 날짜를 기준으로 계산한다" do
    with_payout_env("PAYOUT_DUE_DAYS" => "3") do
      Time.use_zone("UTC") do
        assert_equal Date.new(2026, 11, 3), PaymentInstruction.new.due_on(Time.utc(2026, 10, 30, 16))
      end
    end
  end

  private

  def with_payout_env(values)
    keys = %w[PAYOUT_BANK PAYOUT_ACCOUNT PAYOUT_HOLDER PAYOUT_DUE_DAYS PAYOUT_CONTACT]
    previous = ENV.to_h.slice(*keys)
    keys.each { |key| ENV.delete(key) }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    keys.each { |key| ENV[key] = previous[key] }
  end
end
