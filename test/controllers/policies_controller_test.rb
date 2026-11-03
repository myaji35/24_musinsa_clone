require "test_helper"

class PoliciesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_privacy = Rails.configuration.x.privacy
    Rails.configuration.x.privacy = {}
  end

  teardown do
    Rails.configuration.x.privacy = @original_privacy
  end

  test "로그인 없이 처리방침과 설정의 보유 기간을 표시한다" do
    get privacy_policy_path

    assert_response :success
    assert_select "h1", text: "개인정보처리방침"
    assert_includes response.body, "배송 완료 후 #{Rails.configuration.x.shipping_address_retention_days}일"
    assert_includes response.body, "주문일 기준 #{Rails.configuration.x.order_record_retention_years}년"
    assert_includes response.body, "접수 후 #{Feedback::CONTACT_RETENTION_DAYS}일"
    assert_select "article section", count: 9
    assert_includes response.body, "JIEUM"
    assert_includes response.body, "보호책임자 정보 준비 중"
    assert_includes response.body, "위탁 업체 정보 준비 중입니다."
    assert_select "article a[href=?]", new_feedback_path
    assert_not_includes response.body, "시행일:"
  end

  test "보관 기간은 고정 문구가 아니라 설정을 따른다" do
    original_days = Rails.configuration.x.shipping_address_retention_days
    original_years = Rails.configuration.x.order_record_retention_years
    Rails.configuration.x.shipping_address_retention_days = 123
    Rails.configuration.x.order_record_retention_years = 7

    get privacy_policy_path

    assert_includes response.body, "배송 완료 후 123일"
    assert_includes response.body, "주문일 기준 7년"
  ensure
    Rails.configuration.x.shipping_address_retention_days = original_days
    Rails.configuration.x.order_record_retention_years = original_years
  end

  test "사업자 설정의 이름 연락처 위탁 목록과 시행일을 표시한다" do
    Rails.configuration.x.privacy = {
      business_name: "테스트 상호", officer_name: "테스트 책임자",
      officer_contact: "privacy@example.test", processors: "배송 업체, 보관 업체",
      effective_date: "2026-11-01"
    }

    get privacy_policy_path

    assert_response :success
    assert_includes response.body, "테스트 상호"
    assert_select "dd", text: "테스트 책임자"
    assert_select "dd", text: "privacy@example.test"
    assert_select "li", text: "배송 업체"
    assert_select "li", text: "보관 업체"
    assert_includes response.body, "시행일: 2026-11-01"
    assert_not_includes response.body, "정보 준비 중"
  ensure
    Rails.configuration.x.privacy = @original_privacy
  end

  test "저장된 실제 개인정보를 화면에 표시하지 않는다" do
    address = ShippingAddress.create!(
      recipient_name: "비공개수령인", phone: "010-8765-4321", postal_code: "06543",
      address1: "비공개주소 123", address2: "비공개상세 456", country_code: "KR"
    )
    feedback = Feedback.create!(kind: "other", body: "개인정보가 화면에 노출되지 않는지 확인합니다.",
                                contact_email: "hidden@example.test", contact_consent: true,
                                reporter_hash: "private-reporter-hash")

    get privacy_policy_path

    assert_response :success
    [ address.recipient_name, address.phone, address.postal_code, address.address1, address.address2,
      feedback.contact_email, feedback.reporter_hash, users(:one).email, users(:one).name ].each do |value|
      assert_not_includes response.body, value
    end
  end
end
