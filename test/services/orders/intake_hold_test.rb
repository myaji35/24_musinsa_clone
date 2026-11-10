require "test_helper"

class Orders::IntakeHoldTest < ActiveSupport::TestCase
  setup do
    @variant = variants(:one)
    @address = { recipient_name: "홍길동", phone: "010-7777-9876", postal_code: "06123", address1: "서울시 테스트로 1" }
  end

  test "홀드 주문은 이중 차감 없이 전환하고 취소 시 주문 수량만 복원한다" do
    hold = reserve(2)
    result = intake(2, hold)
    assert result.success?, result.errors.inspect
    assert_equal 3, @variant.reload.stock
    assert_equal "converted", hold.reload.status
    assert_equal result.orders.first.id, hold.order_id
    assert_equal false, Inventory::StockHoldService.release(hold.token).data
    assert_equal 1, StockLog.where(variant: @variant, note: "방송 홀드 #{hold.token}").count
    result.orders.first.cancel!
    assert_equal 5, @variant.reload.stock
  end

  test "초과 홀드 수량은 즉시 복원한다" do
    hold = reserve(4)
    assert intake(2, hold).success?
    assert_equal 3, @variant.reload.stock
    assert_equal 2, StockLog.where(note: "방송 홀드 잔량 복원 #{hold.token}").sum(:quantity)
  end

  test "만료 홀드는 일반 차감하고 만료 해제로 원래 홀드만 복원한다" do
    hold = reserve(2)
    travel_to hold.expires_at, with_usec: true do
      assert intake(2, hold).success?
      assert_equal 1, @variant.reload.stock
      assert_equal "held", hold.reload.status
      Inventory::StockHoldService.release_expired
      assert_equal 3, @variant.reload.stock
    end
  end

  test "다른 옵션과 부족한 홀드 및 재사용 토큰은 일반 차감한다" do
    hold = reserve(1)
    assert intake(2, hold).success?
    assert_equal "held", hold.reload.status
    assert intake(1, hold).success?
    assert intake(1, hold).success?
    assert_equal 1, @variant.reload.stock
    variants(:two).update!(stock: 2)
    result = Orders::Intake.call(items: [ { variant_id: variants(:two).id, quantity: 1 } ],
                                 address: @address, hold_tokens: { variants(:two).id => hold.token })
    assert result.success?
    assert_equal 1, variants(:two).reload.stock
  end

  test "후속 품목 실패 시 전환과 잔량 복원도 롤백한다" do
    hold = reserve(4)
    result = Orders::Intake.call(items: [ { variant_id: @variant.id, quantity: 2 }, { variant_id: -1, quantity: 1 } ],
                                 address: @address, hold_tokens: { @variant.id => hold.token })
    assert result.failure?
    assert_equal "held", hold.reload.status
    assert_nil hold.order_id
    assert_equal 1, @variant.reload.stock
    assert_not StockLog.exists?(note: "방송 홀드 잔량 복원 #{hold.token}")
  end

  private

  def reserve(quantity)
    Inventory::StockHoldService.reserve(variant_id: @variant.id, quantity: quantity).data
  end

  def intake(quantity, hold)
    Orders::Intake.call(items: [ { variant_id: @variant.id, quantity: quantity } ],
                        address: @address, hold_tokens: { @variant.id => hold.token })
  end
end
