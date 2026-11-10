require "test_helper"

class BusinessDisclosuresTest < ActionDispatch::IntegrationTest
  setup do
    @original_business = Rails.configuration.x.business
    @original_date = ENV["TERMS_EFFECTIVE_DATE"]
    Rails.configuration.x.business = {}
    ENV.delete("TERMS_EFFECTIVE_DATE")
  end

  teardown do
    Rails.configuration.x.business = @original_business
    ENV["TERMS_EFFECTIVE_DATE"] = @original_date
  end

  test "사업자 미설정이면 푸터의 모든 항목은 준비 중이고 가짜 번호나 확인 링크가 없다" do
    get root_path

    assert_response :success
    assert_select 'footer div[role="region"][aria-label="사업자 정보"]' do
      assert_select "dd", text: "등록 준비 중", count: BusinessInfo::LABELS.size
      assert_select 'a[href*="bizCommPop"]', count: 0
      assert_no_match(/\d{3}-\d{2}-\d{5}|\d{2,3}-\d{3,4}-\d{4}/, css_select("dd").map(&:text).join)
    end
    assert_select "footer a[href=?]", terms_policy_path, text: "이용약관"
    assert_not BusinessInfo.new.complete?
    assert_equal BusinessInfo::LABELS.values, BusinessInfo.new.missing_labels
  end

  test "설정한 사업자 값은 UTF8로 표시하고 숫자만 사용해 공정위 링크를 만든다" do
    values = {
      name: "검증용 상호", representative: "검증용 대표", address: "검증용 주소",
      phone: "검증용 전화", email: "검증용 이메일", registration_number: "123-45-67890",
      mail_order_number: "검증용 신고번호", mail_order_agency: "검증용 신고기관",
      hosting_provider: "검증용 호스팅"
    }
    Rails.configuration.x.business = values.transform_values { |value| value.dup.force_encoding(Encoding::ASCII_8BIT) }

    get terms_policy_path

    assert_response :success
    values.each_value { |value| assert_includes response.body, value }
    assert_select 'footer a[href="https://www.ftc.go.kr/bizCommPop.do?wrkr_no=1234567890"]', count: 1
    assert_includes response.body, "검증용 상호(이하"
    assert BusinessInfo.new.complete?
    assert_empty BusinessInfo.new.missing_labels
  end

  test "이용약관은 공개되고 철회 환급 비용 미성년자와 시행일을 안내한다" do
    get terms_policy_path

    assert_response :success
    assert_select "h1", text: "이용약관"
    assert_select 'article > div[role="region"][aria-label="사업자 정보"]', count: 1
    [ "상품 수령 후 7일", "수령 후 3개월", "30일 이내", "반환받은 날부터 3영업일",
      "단순 변심 반품 배송비는 소비자가 부담", "미성년자 또는 법정대리인이 취소",
      "시행일 준비 중", "JIEUM(이하" ].each do |text|
      assert_includes response.body, text
    end

    ENV["TERMS_EFFECTIVE_DATE"] = "검증용 시행일"
    get terms_policy_path
    assert_includes response.body, "시행일: 검증용 시행일"
  end

  test "주문 버튼 앞에 철회 환불 미성년자와 세 정책 링크를 안내한다" do
    post cart_items_path, params: { variant_id: variants(:one).id }
    get new_checkout_path

    assert_response :success
    assert_select 'form section[aria-label="주문 전 확인"]' do
      [ "상품 수령 후 7일", "택 제거·착용으로 상품 가치가 크게 줄어든 경우",
        "반품 도착 후 3영업일", "입금 계좌로", "단순 변심 반품 배송비는 고객 부담",
        "상품 하자·오배송은 판매자 부담", "미성년자 또는 법정대리인이 취소",
        "판매자 상호: 등록 준비 중", "전화: 등록 준비 중", "이메일: 등록 준비 중" ].each do |text|
        assert_includes css_select("section").map(&:text).join, text
      end
      assert_select "a[href=?]", returns_policy_path, text: "배송·반품 안내"
      assert_select "a[href=?]", terms_policy_path, text: "이용약관"
      assert_select "a[href=?]", privacy_policy_path, text: "개인정보처리방침"
    end
    assert_select 'form input[type="submit"][value="주문하기"]', count: 1
  end
end
