require "test_helper"

class Admin::AccessLogsControllerTest < ActionDispatch::IntegrationTest
  test "관리자 조회는 성공하며 조회 자체도 기록한다" do
    sign_in
    assert_difference "AccessLog.count", 1 do
      get admin_access_logs_path
      assert_response :success
    end
    assert_equal "접속기록 조회", AccessLog.order(:id).last.screen
    assert_select "ul.lg\\:hidden"
    assert_select "div.hidden.lg\\:block table"
  end

  test "운영자는 재고 화면으로 이동하고 기록을 남기지 않는다" do
    sign_in(users(:operator))
    assert_no_difference "AccessLog.count" do
      get admin_access_logs_path
      assert_redirected_to inventory_scan_path
    end
  end

  test "기간은 서울 날짜 양끝을 포함하고 화면 필터를 적용한다" do
    sign_in
    first = Time.zone.local(2026, 11, 1)
    last = Time.zone.local(2026, 11, 2).end_of_day
    [ first, last ].each { |time| create_log(time, "주문 관리", "포함 직원") }
    create_log(first - 1.second, "주문 관리", "이전 직원")
    create_log(last + 1.second, "주문 관리", "이후 직원")
    create_log(first, "사용자 관리", "다른 화면 직원")
    get admin_access_logs_path(from: "2026-11-01", to: "2026-11-02", screen: "주문 관리")
    assert_response :success
    assert_select "tbody tr", count: 2
    assert_select "tbody td", text: /포함 직원/, count: 2
    assert_select "tbody td", text: /이전 직원|이후 직원|다른 화면 직원/, count: 0
  end

  test "최신순 오십 건씩 표시하고 페이지 링크에 필터를 유지한다" do
    sign_in
    freeze_time do
      51.times { |i| create_log(i.minutes.ago, "주문 관리", "직원 #{i}") }
      get admin_access_logs_path(screen: "주문 관리")
      assert_select "tbody tr", count: 50
      assert_select "tbody tr:first-child td", text: "직원 0 (ID: )"
      assert_select "tbody td", text: "직원 50 (ID: )", count: 0
      assert_select "nav[aria-label='페이지'] a[href=?]", admin_access_logs_path(screen: "주문 관리", page: 2), text: "다음"
      get admin_access_logs_path(screen: "주문 관리", page: 2)
      assert_select "tbody tr", count: 1
      assert_select "tbody td", text: "직원 50 (ID: )"
    end
  end

  test "잘못된 날짜는 무시하고 정상 응답한다" do
    sign_in
    get admin_access_logs_path(from: "잘못된 날짜", to: "2026-99-99")
    assert_response :success
  end

  private

  def create_log(time, screen, label)
    AccessLog.create!(screen: screen, action: "index", user_label: label, created_at: time)
  end
end
