require "test_helper"
require "minitest/mock"

class WechatControllerTest < ActionDispatch::IntegrationTest
  setup do
    @contact = WechatContact.create!(account: accounts(:jieum), open_id: "admin-contact", nickname: "工厂")
    @message = @contact.wechat_messages.create!(account: @contact.account, direction: "in", msg_type: "text", content: "你好", status: "received")
    @foreign = WechatContact.create!(account: accounts(:other), open_id: "other-contact", nickname: "foreign-name")
  end

  test "guests cannot access administration or see navigation" do
    get wechat_index_path
    assert_redirected_to login_path
    get wechat_path(@contact)
    assert_redirected_to login_path
    post send_message_wechat_path(@contact), params: { content: "test" }
    assert_redirected_to login_path
    get root_path
    assert_select "a[href='#{wechat_index_path}']", count: 0
  end

  test "admin reads conversations marks read and connects only same tenant suppliers" do
    sign_in
    get wechat_index_path
    assert_response :success
    assert_includes response.body, "工厂"
    refute_includes response.body, "foreign-name"
    assert_equal 1, @contact.unread_count
    get wechat_path(@contact)
    assert_response :success
    assert_equal 0, @contact.reload.unread_count
    patch wechat_path(@contact), params: { supplier_id: suppliers(:one).id }
    assert_equal suppliers(:one), @contact.reload.supplier
    foreign_supplier = Supplier.create!(account: accounts(:other), name: "foreign", phone: "123")
    patch wechat_path(@contact), params: { supplier_id: foreign_supplier.id }
    assert_response :not_found
    assert_equal suppliers(:one), @contact.reload.supplier
    [:get, :patch].each do |verb|
      public_send(verb, wechat_path(@foreign))
      assert_response :not_found
    end
    post send_message_wechat_path(@foreign), params: { content: "test" }
    assert_response :not_found
  end

  test "other account member is blocked by existing admin authorization" do
    post login_path, params: { email: users(:other).email, password: "TestPassword!2026" }
    get wechat_index_path
    assert_redirected_to workspace_path
  end

  test "settings expose presence only and disabled manual sending persists" do
    sign_in
    original = ENV.to_h.slice("WECHAT_APP_SECRET", "WECHAT_SEND_ENABLED")
    ENV["WECHAT_APP_SECRET"] = "secret-never-render"
    ENV["WECHAT_SEND_ENABLED"] = "false"
    get wechat_index_path
    refute_includes response.body, "secret-never-render"
    assert_includes response.body, "시크릿: 있음"
    assert_difference "WechatMessage.count", 1 do
      post send_message_wechat_path(@contact), params: { content: "안녕하세요" }
    end
    assert_equal "disabled", @contact.wechat_messages.order(:id).last.status
    assert_no_difference "WechatMessage.count" do
      post send_message_wechat_path(@contact), params: { content: "x" * 2001 }
    end
  ensure
    %w[WECHAT_APP_SECRET WECHAT_SEND_ENABLED].each { |key| original[key] ? ENV[key] = original[key] : ENV.delete(key) }
  end
end
