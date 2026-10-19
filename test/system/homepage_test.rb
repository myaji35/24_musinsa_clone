require "application_system_test_case"

class HomepageTest < ApplicationSystemTestCase
  setup do
    YAML.load_file(Rails.root.join("config/characters.yml")).each do |attributes|
      Character.create!(attributes)
    end
  end

  test "런웨이 재생 버튼은 선택한 영상만 로드하고 재생한다" do
    visit root_url
    assert_selector ".intro-reel video[src]", count: 0, visible: :all
    button = find(".intro-reel button", match: :first)
    button.click
    assert_selector '.intro-reel button[aria-pressed="true"]', count: 1
    assert evaluate_script('document.querySelector(".intro-reel video").src.endsWith(".mp4")')
    assert evaluate_script('!document.querySelector(".intro-reel video").paused')
    button.click
    assert_selector '.intro-reel button[aria-pressed="true"]', count: 0
  end

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
  end

  # 시나리오 2: 현재 홈 인트로 확인
  test "홈 인트로가 표시되는가" do
    visit root_url

    assert_selector ".intro-card-photo", count: 10, visible: :all
    assert_selector ".intro-card-soon", text: "곧 공개", count: 10, visible: :all
    assert_selector ".intro-card-virtual", text: "가상 인물", count: 10, visible: :all
    assert_selector 'img[alt="강유나 (AI 가상 인물)"]', visible: :all
    assert_selector ".intro-characters h2", text: "20명의 캐릭터, 20개의 옷장"
    assert_selector ".intro-card", count: 20, visible: :all
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
    within ".max-w-md form" do
      fill_in "q", with: "coat"
      find("button[type='submit']").click
    end

    # 검색 결과 확인
    assert_selector ".grid"
  end

  # 시나리오 5: 카테고리 필터 테스트
  test "카테고리 필터가 작동하는가" do
    visit root_path

    # 아우터 카테고리 클릭
    within "#ranking" do
      click_link "아우터"
    end

    # URL에 category 파라미터가 있는가
    assert_current_path root_path(category: "아우터")

    # 상품이 표시되는가
    assert_selector ".grid"
  end
end
