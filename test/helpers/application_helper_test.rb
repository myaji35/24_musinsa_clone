require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "관리 금액은 소수점 없이 원화로 표시한다" do
    assert_equal "₩1,975,000", admin_krw(1975000.0)
    assert_equal "₩1,235", admin_krw(BigDecimal("1234.5"))
  end

  test "관리 금액이 없으면 0원으로 표시한다" do
    assert_equal "₩0", admin_krw(nil)
  end

  test "가격을 원화 기호와 천 단위 구분자로 표시한다" do
    assert_dom_equal '<span class="price">₩ 239,000</span>', price_won(239000)
  end

  test "큰 할인가와 정수 가격을 표시한다" do
    assert_dom_equal '<span class="price price-lg price-sale">₩ 1,234</span>', price_won(1234.9, variant: :lg, sale: true)
  end

  test "시각을 서울 시간으로 표시한다" do
    assert_equal "2026-10-13 18:28", seoul_datetime(Time.utc(2026, 10, 13, 9, 28))
  end
end
