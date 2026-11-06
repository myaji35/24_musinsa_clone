require "test_helper"

class WorkspaceKakaoExtractionsControllerTest < ActionDispatch::IntegrationTest
  test "Korean labels and future settlement errors appear in approval" do
    sign_in
    account = accounts(:jieum)
    room = account.kakao_rooms.create!(name: "입금 약속")
    extraction = account.kakao_extractions.create!(kakao_room: room, supplier: suppliers(:one), kind: "payment", progress: "planned", summary: "입금 약속", date: Date.tomorrow, amount: 1560000)
    get workspace_kakao_extraction_path(extraction)
    assert_select 'option[value="payment"]', text: "입금·지급"
    assert_select 'option[value="planned"][selected]', text: "예정"
    assert_select 'select[name="target"] option[value="schedule"][selected]'
    post approve_workspace_kakao_extraction_path(extraction), params: { extraction: { progress: "done" }, target: "receipt" }
    assert_response :unprocessable_entity
    assert_includes response.body, "미래 날짜의 수금·지급은 기록할 수 없습니다 — 일정으로 반영해 주세요"
    assert_equal "pending", extraction.reload.status
    assert_equal "planned", extraction.progress
  end

  test "inbox forms and account isolation" do
    sign_in
    room = accounts(:jieum).kakao_rooms.create!(name: "승인함 테스트")
    extraction = accounts(:jieum).kakao_extractions.create!(kakao_room: room, kind: "schedule", summary: "회의", date: Date.current)
    get workspace_kakao_inbox_path
    assert_response :success
    get workspace_kakao_extraction_path(extraction)
    assert_response :success
    get workspace_kakao_gaps_path
    assert_response :success
    foreign_room = accounts(:other).kakao_rooms.create!(name: "외부 방")
    foreign = accounts(:other).kakao_extractions.create!(kakao_room: foreign_room, kind: "issue", summary: "외부")
    get workspace_kakao_extraction_path(foreign)
    assert_response :not_found
    post approve_workspace_kakao_extraction_path(foreign), params: { extraction: { summary: "침입" }, target: "record" }
    assert_response :not_found
    post analyze_workspace_kakao_room_path(foreign_room)
    assert_response :not_found
    post approve_workspace_kakao_extraction_path(extraction), params: { extraction: { summary: "회의" }, target: "sale" }
    assert_response :unprocessable_entity
    assert_includes response.body, "거래처를 선택해 주세요"
    post approve_workspace_kakao_extraction_path(extraction), params: { extraction: { supplier_id: suppliers(:one).id }, target: "receipt" }
    assert_response :unprocessable_entity
    assert_includes response.body, "금액을 입력해 주세요"
    foreign_supplier = accounts(:other).suppliers.create!(name: "외부", phone: "010")
    post approve_workspace_kakao_extraction_path(extraction), params: { extraction: { supplier_id: foreign_supplier.id }, target: "record" }
    assert_response :not_found
    post approve_workspace_kakao_extraction_path(extraction), params: { extraction: { summary: "회의" }, target: "schedule" }
    assert_redirected_to workspace_kakao_inbox_path
    assert_equal "approved", extraction.reload.status
    message = room.kakao_messages.create!(account: room.account, body: "내일 확인", sent_at: Time.current, extraction_gap: true)
    post workspace_kakao_extractions_path, params: { message_id: message.id }
    manual = room.kakao_extractions.where(status: "pending").sole
    assert_redirected_to workspace_kakao_extraction_path(manual)
    assert_equal [ message.id ], manual.kakao_message_ids
    assert_not message.reload.extraction_gap?
    post reject_workspace_kakao_extraction_path(manual)
    assert_equal "rejected", manual.reload.status
  end
end
