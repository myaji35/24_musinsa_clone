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
    assert_select '[role="status"]', text: /생성 4건, 갱신 0건/
    assert_select "td", text: "코트"
    assert_select "p", text: /코트 · .*최근 지수/
  end

  test "파일 누락과 잘못된 헤더를 안내한다" do
    sign_in
    post trends_path
    assert_match "파일을 선택", flash[:alert]
  end
  test "재업로드 갱신 결과를 표시하고 다음 요청에서 알림이 사라진다" do
    sign_in
    2.times do |index|
      post trends_path, params: { file: fixture_file_upload("datalab_trends.csv", "text/csv") }
      follow_redirect!
      assert_select '[role="status"]', text: /#{index.zero? ? "생성 4건, 갱신 0건" : "생성 0건, 갱신 4건"}/
      get inventory_scan_path
      assert_response :success
      assert_empty flash.to_hash
      assert_select '[role="status"]', text: /생성 .*갱신/, count: 0
    end
  end

  test "잘못된 CSV와 바이너리 업로드 오류를 표시하고 다음 요청에 남기지 않는다" do
    sign_in
    [ "날짜,코트\n\"닫히지 않은 값", "\xFF\xFE\x00\x81".b, "잘못된 헤더" ].each do |content|
      file = Tempfile.new([ "invalid", ".csv" ])
      begin
        file.binmode
        file.write(content)
        file.rewind
        assert_no_difference("TrendSnapshot.count") do
          post trends_path, params: { file: Rack::Test::UploadedFile.new(file.path, "text/csv") }
        end
        assert_redirected_to trends_path
        follow_redirect!
        message = content == "잘못된 헤더" ? "날짜/기간/period로 시작하는 CSV 헤더를 찾을 수 없습니다." :
          "CSV 파일을 읽을 수 없습니다. 데이터랩에서 내려받은 CSV(UTF-8 또는 엑셀 CSV)인지 확인하세요."
        assert_select '[role="alert"]', text: message
        get inventory_scan_path
        assert_response :success
        assert_empty flash.to_hash
        assert_not_includes response.body, message
      ensure
        file.close!
      end
    end
  end

  test "추천 데이터가 있는 캐릭터만 표에 표시하고 나머지는 요약한다" do
    sign_in
    Character.create!(name: "미추천 캐릭터", handle: "trend_empty", age_band: 20, wardrobe: "신발")
    Character.create!(name: "추천 캐릭터", handle: "trend_ready", age_band: 30, wardrobe: "코트")
    TrendSnapshot.store!(source: "datalab_csv", series_name: "코트", period_start: Date.current.beginning_of_week,
      ratio: 30, age_band: 30, gender: nil, imported_at: Time.current)
    get trends_path
    assert_select "tbody td", text: "추천 캐릭터"
    assert_select "tbody td", text: "미추천 캐릭터", count: 0
    assert_select "p", text: /데이터 없음: .*미추천 캐릭터.*담당 의류 CSV를 올리면 추천이 표시됩니다/
  end
end
