require "test_helper"

class KpiCalculatorTest < ActiveSupport::TestCase
  test "목표와 override, 마진, 손익분기를 계산한다" do
    calculator = Kpi::Calculator.new
    product = products(:one)
    analysis = product.product_analyses.create!(status: "done")
    assert_equal 2, calculator.target_units
    calculator.assign_target!(analysis)
    assert_equal 39_800, analysis.reload.target_revenue
    assert_nil calculator.row(product).unit_margin
    product.update!(supply_price: 10_000)
    assert_equal 9_900, calculator.row(product).unit_margin
    assert_equal 1, calculator.row(product).breakeven_units
    analysis.update!(target_units_override: 5)
    calculator.assign_target!(analysis)
    assert_equal 5, analysis.reload.target_units
    assert_equal 99_500, analysis.target_revenue
  end

  test "유효 주문 상태와 기간만 실적으로 계산한다" do
    calculator = Kpi::Calculator.new
    product = products(:one)
    assert_equal 39_800, calculator.actual_for(product.id)
    orders(:one).update!(status: "cancelled")
    assert_equal 0, calculator.actual_for(product.id)
    orders(:one).update!(status: "paid", created_at: 31.days.ago)
    assert_equal 0, calculator.actual_for(product.id)
  end

  test "목표 0이면 달성률이 없다" do
    assert_nil Kpi::Calculator.new.achievement(100, 0)
  end
end
