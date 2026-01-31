require "application_system_test_case"

class HomepageTest < ApplicationSystemTestCase
  # 시나리오 1: 홈페이지 접속 및 기본 요소 확인
  test "홈페이지가 정상적으로 로드되는가" do
    visit root_url

    # 타이틀 확인
    assert_selector "title", text: "JIEUN", visible: false

    # 로고 확인
    assert_text "JIEUN"

    # 랭킹 섹션 확인
    assert_text "무신사 랭킹"

    # 상품 카드가 표시되는가
    assert_selector ".grid", minimum: 1

    # 스크린샷 저장 (디버깅용)
    take_screenshot
  end

  # 시나리오 2: 29cm 큐레이션 섹션 확인
  test "29cm 스타일 큐레이션 섹션이 표시되는가" do
    visit root_url

    # 큐레이션 섹션 헤더 확인
    assert_text "미니멀 컬렉션", count: 1

    # 큐레이션 상품 카드가 있는가
    within first(".mb-16") do
      assert_selector ".grid", minimum: 1
      assert_selector "img[src*='unsplash']", minimum: 1
    end
  end

  # 시나리오 3: 네비게이션 테스트
  test "주요 메뉴 네비게이션이 작동하는가" do
    visit root_url

    # 상품 메뉴 클릭
    click_link "상품", match: :first
    assert_current_path products_path

    # 홈으로 돌아가기
    click_link "JIEUN"
    assert_current_path root_path
  end

  # 시나리오 4: 검색 기능 테스트
  test "검색 기능이 작동하는가" do
    visit root_path

    # 검색어 입력
    fill_in "q", with: "coat"

    # 검색 실행
    find("button[type='submit']").click

    # 검색 결과 확인
    assert_selector ".grid"
  end

  # 시나리오 5: 카테고리 필터 테스트
  test "카테고리 필터가 작동하는가" do
    visit root_path

    # 아우터 카테고리 클릭
    click_link "아우터"

    # URL에 category 파라미터가 있는가
    assert_match /category=%EC%95%84%EC%9A%B0%ED%84%B0/, current_url

    # 상품이 표시되는가
    assert_selector ".grid"
  end
end
