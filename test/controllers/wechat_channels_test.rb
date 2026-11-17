require "test_helper"

class WechatChannelsTest < ActionDispatch::IntegrationTest
  setup do
    @mac_auto_send = ENV.delete("WECHAT_MAC_AUTO_SEND")
    @account = accounts(:jieum)
    @contact = @account.wechat_contacts.create!(wechat_display_name: "工厂", supplier: suppliers(:one))
  end

  teardown do
    @mac_auto_send.nil? ? ENV.delete("WECHAT_MAC_AUTO_SEND") : ENV["WECHAT_MAC_AUTO_SEND"] = @mac_auto_send
  end

  test "channel changes require administrator and are validated" do
    patch channel_wechat_index_path, params: { wechat_channel_mode: "mac_app" }
    assert_redirected_to login_path
    post login_path, params: { email: users(:other).email, password: "TestPassword!2026" }
    patch channel_wechat_index_path, params: { wechat_channel_mode: "mac_app" }
    assert_redirected_to workspace_path
    delete logout_path
    sign_in
    patch channel_wechat_index_path, params: { wechat_channel_mode: "bad" }
    assert_response :unprocessable_entity
    patch channel_wechat_index_path, params: { wechat_channel_mode: "mac_app" }
    assert_equal "mac_app", @account.reload.wechat_channel_mode
  end

  test "manual purchase notice completion reply and contact creation" do
    sign_in
    Wechat::PurchaseOrderNotifier.call(purchase_orders(:one), sent_by: users(:one))
    message = @contact.wechat_messages.last
    assert_equal "pending_manual", message.status
    assert_includes message.content, "新订单 / 신규 발주"
    get purchase_order_path(purchase_orders(:one))
    assert_includes response.body, "보냈음 표시"
    post complete_wechat_index_path(message_id: message.id)
    assert_equal "sent_manual", message.reload.status
    assert_equal users(:one), message.processed_by
    assert message.processed_at
    get purchase_order_path(purchase_orders(:one))
    assert_response :success
    assert_includes response.body, users(:one).name
    post complete_wechat_index_path(message_id: message.id)
    assert_response :conflict
    post receive_message_wechat_path(@contact), params: { content: "收到 / 확인" }
    assert_equal "received_manual", @contact.wechat_messages.last.status
    assert @contact.reload.last_inbound_at
    post wechat_index_path, params: { supplier_id: suppliers(:one).id, wechat_display_name: "새 공장" }
    assert_equal "새 공장", @account.wechat_contacts.last.wechat_display_name
    get wechat_path(@contact)
    assert_includes response.body, "받은 메시지 붙여넣기"
  end

  test "mac app defaults to manual purchase notices and conversations and rejects approval" do
    sign_in
    @account.update!(wechat_channel_mode: "mac_app")
    Wechat::PurchaseOrderNotifier.call(purchase_orders(:one), sent_by: users(:one))
    notice = @contact.wechat_messages.last
    assert_equal "pending_manual", notice.status
    get purchase_order_path(purchase_orders(:one))
    assert_includes response.body, "보냈음 표시"
    refute_includes response.body, "보내기 승인"
    post send_message_wechat_path(@contact), params: { content: "수동 대화" }
    message = @contact.wechat_messages.last
    assert_equal "pending_manual", message.status
    post complete_wechat_index_path(message_id: message.id)
    assert_equal "sent_manual", message.reload.status
    assert_equal users(:one), message.processed_by
    assert message.processed_at
    post complete_wechat_index_path(message_id: message.id)
    assert_response :conflict
    notice.update!(status: "awaiting_approval")
    get wechat_path(@contact)
    refute_includes response.body, "보내기 승인"
    post complete_wechat_index_path(message_id: notice.id)
    assert_response :unprocessable_entity
    assert_equal "awaiting_approval", notice.reload.status
    get wechat_index_path
    assert_includes response.body, "자동 발송: 꺼짐"
  end

  test "mac app purchase notices use approval only for exact true" do
    sign_in
    @account.update!(wechat_channel_mode: "mac_app")
    %w[false TRUE 1].each do |value|
      ENV["WECHAT_MAC_AUTO_SEND"] = value
      Wechat::PurchaseOrderNotifier.call(purchase_orders(:one), sent_by: users(:one))
      assert_equal "pending_manual", @contact.wechat_messages.last.status
    end
    ENV["WECHAT_MAC_AUTO_SEND"] = "true"
    Wechat::PurchaseOrderNotifier.call(purchase_orders(:one), sent_by: users(:one))
    message = @contact.wechat_messages.last
    assert_equal "awaiting_approval", message.status
    get purchase_order_path(purchase_orders(:one))
    assert_includes response.body, "보내기 승인"
    post complete_wechat_index_path(message_id: message.id)
    assert_equal "queued_mac", message.reload.status
    get wechat_index_path
    assert_includes response.body, "자동 발송: 켜짐"
  end

  test "tokens are shown once digested and revocable" do
    sign_in
    @account.update!(wechat_channel_mode: "mac_app")
    post issue_token_wechat_index_path, params: { name: "운영 맥" }
    assert_response :success
    raw = response.body[/<code>([a-f0-9]{64})<\/code>/, 1]
    assert raw
    token = @account.wechat_agent_tokens.last
    assert_equal Digest::SHA256.hexdigest(raw), token.token_digest
    refute_equal raw, token.token_digest
    get wechat_index_path
    refute_includes response.body, raw
    foreign, = WechatAgentToken.issue!(account: accounts(:other), name: "다른 맥")
    delete revoke_token_wechat_index_path(token_id: foreign.id)
    assert_response :not_found
    assert_nil foreign.reload.revoked_at
    delete revoke_token_wechat_index_path(token_id: token.id)
    assert token.reload.revoked_at
    post "/api/wechat_agent/heartbeat", headers: { "Authorization" => "Bearer #{raw}" }
    assert_response :unauthorized
  end

  test "official contacts require open id" do
    @account.update!(wechat_channel_mode: "official")
    refute @account.wechat_contacts.build(wechat_display_name: "official").valid?
  end
end
