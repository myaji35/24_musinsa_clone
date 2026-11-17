require "test_helper"

class WechatAgentTest < ActionDispatch::IntegrationTest
  setup do
    @mac_auto_send = ENV.delete("WECHAT_MAC_AUTO_SEND")
    @account = accounts(:jieum)
    @account.update!(wechat_channel_mode: "mac_app")
    @token, raw = WechatAgentToken.issue!(account: @account, name: "Mac")
    @headers = { "Authorization" => "Bearer #{raw}" }
    @contact = @account.wechat_contacts.create!(wechat_display_name: "工厂")
  end

  teardown do
    @mac_auto_send.nil? ? ENV.delete("WECHAT_MAC_AUTO_SEND") : ENV["WECHAT_MAC_AUTO_SEND"] = @mac_auto_send
  end

  test "invalid tokens fail and heartbeat updates disconnect warning" do
    post "/api/wechat_agent/heartbeat", headers: { "Authorization" => "Bearer invalid" }
    assert_response :unauthorized
    sign_in
    get wechat_index_path
    assert_includes response.body, "연결 끊김"
    post "/api/wechat_agent/heartbeat", headers: @headers
    assert_response :no_content
    assert @token.reload.last_seen_at
    get wechat_index_path
    refute_includes response.body, "연결 끊김"
    travel 6.minutes do
      get wechat_index_path
      assert_includes response.body, "연결 끊김"
    end
  end

  test "disabled automatic sending hides previously queued messages but allows inbox" do
    @contact.wechat_messages.create!(account: @account, direction: "out", msg_type: "text", content: "queued", status: "queued_mac")
    get "/api/wechat_agent/outbox", headers: @headers
    assert_equal [], response.parsed_body
    post "/api/wechat_agent/inbox", headers: @headers, params: { display_name: "工厂", content: "你好", external_key: "manual-mode-inbox" }, as: :json
    assert_response :no_content
    assert_equal "received_mac", @contact.wechat_messages.last.status
  end

  test "outbox requires approval and isolates results and inbox per tenant" do
    ENV["WECHAT_MAC_AUTO_SEND"] = "true"
    message = Wechat::Client.new.send_text(contact: @contact, content: "订单")
    assert_equal "awaiting_approval", message.status
    get "/api/wechat_agent/outbox", headers: @headers
    assert_equal [], response.parsed_body
    sign_in
    post complete_wechat_index_path(message_id: message.id)
    assert_equal "queued_mac", message.reload.status
    foreign_account = accounts(:other)
    foreign_account.update!(wechat_channel_mode: "mac_app")
    foreign_contact = foreign_account.wechat_contacts.create!(wechat_display_name: "工厂")
    foreign = foreign_contact.wechat_messages.create!(account: foreign_account, direction: "out", msg_type: "text", content: "foreign", status: "queued_mac")
    get "/api/wechat_agent/outbox", headers: @headers
    assert_equal [ message.id ], response.parsed_body.map { |row| row["id"] }
    post "/api/wechat_agent/outbox/#{foreign.id}/result", headers: @headers, params: { ok: true }, as: :json
    assert_response :not_found
    post "/api/wechat_agent/outbox/#{message.id}/result", headers: @headers, params: { ok: true }, as: :json
    assert_equal "sent_mac", message.reload.status
    post "/api/wechat_agent/outbox/#{message.id}/result", headers: @headers, params: { ok: false }, as: :json
    assert_response :conflict
    assert_difference "WechatMessage.count", 1 do
      2.times do
        post "/api/wechat_agent/inbox", headers: @headers, params: { display_name: "새 담당자", content: "你好", external_key: "rec-1", received_at: Time.current.iso8601 }, as: :json
        assert_response :no_content
      end
    end
    inbound = @account.wechat_messages.find_by!(external_key: "rec-1")
    assert_nil inbound.wechat_contact.supplier
    assert_equal "새 담당자", inbound.wechat_contact.wechat_display_name
    assert_equal "received_mac", inbound.status
    assert_nil foreign_account.wechat_messages.find_by(external_key: "rec-1")
  end
end
