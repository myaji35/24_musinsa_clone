require "test_helper"

class TrendsControllerTest < ActionDispatch::IntegrationTest
  test "게스트는 조회와 업로드가 차단된다" do
    get trends_path
    assert_redirected_to login_path
    post trends_path
    assert_redirected_to login_path
  end

  test "관리자는 빈 상태와 업로드 결과를 확인한다" do
    sign_in
    Character.create!(name: "트렌드 캐릭터", handle: "trend_test", age_band: 30, wardrobe: "코트·니트")
    get trends_path
    assert_response :success
    assert_select "p", text: /아직 트렌드 데이터가 없습니다/
    assert_select "a[href=?]", trends_path, text: "트렌드"
    assert_difference("TrendSnapshot.count", 4) do
      post trends_path, params: { file: fixture_file_upload("datalab_trends.csv", "text/csv"), age_band: "30", note: "주간 실측" }
    end
    assert_redirected_to trends_path
    assert_match "생성 4건", flash[:notice]
    follow_redirect!
    assert_response :success
    assert_select "td", text: "코트"
    assert_select "p", text: /코트 · .*최근 지수/
  end

  test "파일 누락과 잘못된 헤더를 안내한다" do
    sign_in
    post trends_path
    assert_match "파일을 선택", flash[:alert]
  end
end
