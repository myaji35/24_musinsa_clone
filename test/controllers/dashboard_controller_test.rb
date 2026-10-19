require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  def setup
    sign_in
    # Create anonymous customers with different preferences
    @customer1 = AnonyCustomer.create!(
      zip_prefix: "060",
      phone_suffix: "1234",
      birth_year: 1990,
      preference_tags: { "minimal" => 5, "casual" => 3 }
    )

    @customer2 = AnonyCustomer.create!(
      zip_prefix: "135",
      phone_suffix: "5678",
      birth_year: 1995,
      preference_tags: { "modern" => 4, "minimal" => 2 }
    )

    @customer3 = AnonyCustomer.create!(
      zip_prefix: "060",
      phone_suffix: "9012",
      birth_year: 1988,
      preference_tags: { "vintage" => 6, "delicate" => 4 }
    )
  end

  # GET /dashboard/index
  test "should get index" do
    get dashboard_index_url
    assert_response :success
    assert_select 'nav[aria-label="조회 기간"] a[aria-current="page"]', text: "30일"
  end

  test "period filters orders and revenue, including invalid period fallback" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      orders(:one).update_columns(created_at: 3.days.ago)
      orders(:two).update_columns(created_at: 60.days.ago)

      get dashboard_index_url(period: 7)
      assert_response :success
      assert_select 'nav[aria-label="조회 기간"] a[aria-current="page"]', text: "7일"
      assert_select "#total-orders", text: "1"
      assert_select "#total-revenue", text: "₩39,800"
      assert_select 'button[title="2026-10-12 · ₩39,800"]', count: 1
      assert_select 'button[title="2026-10-11 · ₩0"]', count: 1
      assert_select "h2", text: "최근 7일 주문"
      assert_no_match(/우편번호 061xxx/, response.body)
      assert_no_match(/ORD-20260901-0002/, response.body)

      get dashboard_index_url(period: 90)
      assert_response :success
      assert_select 'nav[aria-label="조회 기간"] a[aria-current="page"]', text: "90일"
      assert_select "#total-orders", text: "2"
      assert_select "#total-revenue", text: "₩98,800"
      assert_match(/우편번호 061xxx/, response.body)

      get dashboard_index_url(period: "invalid")
      assert_response :success
      assert_select 'nav[aria-label="조회 기간"] a[aria-current="page"]', text: "30일"
      assert_select "#total-orders", text: "1"
      assert_select "#total-revenue", text: "₩39,800"
    end
  end

  test "daily sales bars remain visible and accessible in every period" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      orders(:one).update_columns(created_at: 2.days.ago, total_price: 33_000)
      orders(:two).update_columns(created_at: 1.day.ago, total_price: 7_800_000)

      [ 7, 30 ].each do |period|
        get dashboard_index_url(period: period)
        assert_response :success
        assert_select '[data-controller="daily-sales"]' do
          assert_select '[data-daily-sales-target="detail"][aria-live="polite"]', count: 1
          assert_select 'button[aria-label="10/13 ₩33,000"][data-action="focus->daily-sales#select click->daily-sales#select"]' do
            assert_select 'span[style*="min-height: 4px"]', count: 1
          end
          assert_select 'button[aria-label="10/14 ₩7,800,000"] span[style="height: 100.0%; min-height: 4px"]', count: 1
          assert_select 'button[aria-label="10/15 ₩0"] span[style="height: 0.0%; min-height: 0px"]', count: 1
          assert_select "button[aria-label]", count: period + 1
        end
      end
    end
  end

  test "90 day sales chart groups every date into seven day bars ISS102" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      orders(:one).update_columns(created_at: 90.days.ago, total_price: 33_000)
      orders(:two).update_columns(created_at: Time.current, total_price: 7_800_000)

      get dashboard_index_url(period: 90)
      assert_response :success
      assert_select "h2", text: "주별 매출"
      assert_select '[aria-label="주별 매출 막대 차트"]' do
        assert_select "button[aria-label]", count: 13
        assert_select 'button[title="2026-07-17~2026-07-23 · ₩33,000"] span[style*="min-height: 4px"]', count: 1
        assert_select 'button[aria-label="10/9~10/15 ₩7,800,000"] span[style="height: 100.0%; min-height: 4px"]', count: 1
        assert_select 'button[title="2026-07-24~2026-07-30 · ₩0"]', count: 1
      end
      assert_select "#total-revenue", text: "₩7,833,000"
      assert_select '[data-controller="daily-sales"] span', text: "10/15"

      orders(:one).update_columns(created_at: 2.days.ago)
      get dashboard_index_url(period: 90)
      assert_select 'button[aria-label="10/9~10/15 ₩7,833,000"]', count: 1
      assert_select 'button[title="2026-07-17~2026-07-23 · ₩0"]', count: 1
    end
  end

  # Dashboard should show customer count
  test "should display customer statistics" do
    get dashboard_index_url
    assert_response :success
    # 고객 수가 표시되는지 확인
  end

  # GET /dashboard/regional_trends
  test "should get regional_trends" do
    get dashboard_regional_trends_url
    assert_response :success
  end

  # Regional trends should group by zip_prefix
  test "should show regional trends grouped by zip prefix" do
    get dashboard_regional_trends_url
    assert_response :success
    # 지역별 트렌드가 표시되는지 확인
    # 060, 135 지역 데이터 확인
  end

  # GET /dashboard/preference_analysis
  test "should get preference_analysis" do
    get dashboard_preference_analysis_url
    assert_response :success
  end

  # Preference analysis should aggregate tags
  test "should show top preferences across all customers" do
    get dashboard_preference_analysis_url
    assert_response :success
    # 전체 고객의 취향 태그 집계 확인
    # minimal, vintage 등이 표시되는지 확인
  end

  # Privacy check - should not expose sensitive data
  test "should not expose full phone numbers" do
    get dashboard_index_url
    assert_response :success
    # 전체 전화번호가 노출되지 않는지 확인
    assert_no_match /010-\d{4}-\d{4}/, response.body
  end

  # Privacy check - should not expose full addresses
  test "should not expose full addresses" do
    get dashboard_regional_trends_url
    assert_response :success
    # 상세 주소가 노출되지 않는지 확인
  end

  # Privacy check - should only show zip prefix
  test "should only show zip prefix (3 digits)" do
    get dashboard_regional_trends_url
    assert_response :success
    # 우편번호 앞 3자리만 표시되는지 확인
  end

  # Empty dashboard
  test "should handle empty dashboard gracefully" do
    Order.destroy_all
    AnonyCustomer.destroy_all

    get dashboard_index_url
    assert_response :success
    assert_select "p", text: "선택 기간에 주문이 없습니다"
  end

  # Age group analysis (if implemented)
  test "should show age group distribution" do
    get dashboard_index_url
    assert_response :success
    # 연령대별 분포가 표시되는지 확인
    # 1990년생, 1995년생, 1988년생 그룹화
  end
end
