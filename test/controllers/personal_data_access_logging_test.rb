require "test_helper"

class PersonalDataAccessLoggingTest < ActionDispatch::IntegrationTest
  setup do
    @claim = orders(:one).order_claims.create!(kind: "cancel", reason_code: "other",
      requester: "member", user: users(:member))
  end

  test "관리자가 네 개인정보 화면을 열 때마다 마스킹한 접속기록을 한 건 남긴다" do
    sign_in
    screens.each do |path, screen|
      assert_difference "AccessLog.count", 1 do
        get path
        assert_response :success
      end
      log = AccessLog.order(:id).last
      assert_equal users(:one).id, log.user_id
      assert_equal "admin #{AccessLog.mask_email(users(:one).email)}", log.user_label
      assert_not_includes log.user_label, users(:one).email
      assert_equal screen, log.screen
      assert_equal(path == admin_order_claim_path(@claim) ? "show" : "index", log.action)
      assert_equal "127.0.0.1", log.ip
      assert_equal(path == admin_order_claim_path(@claim) ? "OrderClaim" : nil, log.target_type)
      assert_equal(path == admin_order_claim_path(@claim) ? @claim.id : nil, log.target_id)
    end
  end

  test "운영자도 허용된 주문과 클레임 화면 접속을 기록한다" do
    sign_in(users(:operator))
    screens.except(admin_users_path).each do |path, screen|
      assert_difference "AccessLog.count", 1 do
        get path
        assert_response :success
      end
      log = AccessLog.order(:id).last
      assert_equal screen, log.screen
      assert_equal users(:operator).id, log.user_id
      assert_not_includes log.user_label, users(:operator).email
    end
  end

  test "회원과 손님은 개인정보 화면 접근이 거부되고 기록을 남기지 않는다" do
    [ nil, :member ].each do |role|
      post login_path, params: { email: users(role).email, password: "TestPassword!2026" } if role
      (screens.keys + [ admin_access_logs_path ]).each do |path|
        assert_no_difference "AccessLog.count" do
          get path
          assert_redirected_to(role ? root_path : login_path)
        end
      end
    end
  end

  test "기록 저장이 실패해도 네 화면과 접속기록 화면은 정상 응답한다" do
    sign_in
    errors = []
    Rails.logger.stub(:error, ->(message) { errors << message }) do
      AccessLog.stub(:create!, ->(**) { raise ActiveRecord::ActiveRecordError, "저장 실패" }) do
        (screens.keys + [ admin_access_logs_path ]).each do |path|
          get path
          assert_response :success
        end
      end
    end
    assert_equal 5, errors.size
    assert errors.all? { |message| message.include?("개인정보 접속기록 실패") }
  end

  private

  def screens
    { admin_orders_path => "주문 관리", admin_users_path => "사용자 관리",
      admin_order_claims_path => "주문 클레임", admin_order_claim_path(@claim) => "주문 클레임 상세" }
  end
end
