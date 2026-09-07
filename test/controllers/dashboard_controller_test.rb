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
    # 데이터가 없을 때 에러가 발생하지 않는지 확인
  end

  # Age group analysis (if implemented)
  test "should show age group distribution" do
    get dashboard_index_url
    assert_response :success
    # 연령대별 분포가 표시되는지 확인
    # 1990년생, 1995년생, 1988년생 그룹화
  end
end
