require "test_helper"

class WechatWebhookTest < ActionDispatch::IntegrationTest
  setup do
    @env = ENV.to_h.select { |key, _| key.start_with?("WECHAT_") }
    ENV.update("WECHAT_TOKEN" => "test-verification-token", "WECHAT_APP_ID" => "test-app",
      "WECHAT_ENCODING_AES_KEY" => Base64.strict_encode64("k" * 32).delete_suffix("="))
  end

  teardown do
    ENV.keys.grep(/^WECHAT_/).each { |key| ENV.delete(key) }
    ENV.update(@env)
  end

  def signature(encrypted = nil)
    Digest::SHA1.hexdigest([ ENV["WECHAT_TOKEN"], "1700000000", "nonce", encrypted ].compact.sort.join)
  end

  def callback_params
    { timestamp: "1700000000", nonce: "nonce", signature: signature }
  end

  def xml(type: "text", extra: "<Content><![CDATA[新订单 <hello> & 안녕]]></Content>", id: "msg-123")
    "<xml><FromUserName><![CDATA[factory-user]]></FromUserName><CreateTime>#{Time.current.to_i}</CreateTime><MsgType>#{type}</MsgType>#{id ? "<MsgId>#{id}</MsgId>" : ''}#{extra}</xml>"
  end

  def deliver(body, params = callback_params)
    post wechat_webhook_path(params), params: body, headers: { "CONTENT_TYPE" => "application/xml" }
  end

  test "GET signature success and rejection need no authentication" do
    get wechat_webhook_path, params: callback_params.merge(echostr: "challenge")
    assert_response :success
    assert_equal "challenge", response.body
    get wechat_webhook_path, params: callback_params.merge(signature: "bad", echostr: "challenge")
    assert_response :forbidden
    assert_no_difference "WechatMessage.count" do
      deliver(xml, callback_params.merge(signature: "bad"))
      assert_response :forbidden
    end
  end

  test "plaintext CDATA persists in primary tenant and repeated MsgId is ignored" do
    assert_difference "WechatMessage.count", 1 do
      2.times { deliver(xml); assert_response :success; assert_equal "success", response.body }
    end
    message = WechatMessage.find_by!(wechat_msg_id: "msg-123")
    assert_equal "新订单 <hello> & 안녕", message.content
    assert_equal Account.primary, message.account
    assert message.wechat_contact.window_open?
  end

  test "images voice subscribe unsubscribe" do
    deliver(xml(type: "image", extra: "<MediaId>image-1</MediaId>", id: "image"))
    assert_equal "image-1", WechatMessage.find_by!(wechat_msg_id: "image").media_id
    deliver(xml(type: "voice", extra: "<MediaId>voice-1</MediaId><Recognition>你好</Recognition>", id: "voice"))
    assert_equal "你好", WechatMessage.find_by!(wechat_msg_id: "voice").content
    deliver(xml(type: "event", extra: "<Event>unsubscribe</Event>", id: nil))
    refute WechatContact.find_by!(open_id: "factory-user").subscribed?
    deliver(xml(type: "event", extra: "<Event>subscribe</Event>", id: nil))
    assert WechatContact.find_by!(open_id: "factory-user").subscribed?
  end

  test "subscription alone and replayed old messages do not open the 48 hour window" do
    deliver(xml(type: "event", extra: "<Event>subscribe</Event>", id: nil))
    assert_response :success
    contact = WechatContact.find_by!(open_id: "factory-user")
    refute contact.window_open?
    old = xml.sub(/<CreateTime>.*?<\/CreateTime>/, "<CreateTime>#{3.days.ago.to_i}</CreateTime>")
    deliver(old)
    assert_response :success
    refute contact.reload.window_open?
  end

  def encrypt(body, app_id: "test-app", bad_padding: false)
    key = "k" * 32
    raw = "r" * 16 + [ body.bytesize ].pack("N") + body.b + app_id
    padding = 32 - raw.bytesize % 32
    raw += padding.chr * padding
    raw.setbyte(-1, 0) if bad_padding
    cipher = OpenSSL::Cipher.new("AES-256-CBC")
    cipher.encrypt
    cipher.padding = 0
    cipher.key = key
    cipher.iv = key[0, 16]
    Base64.strict_encode64(cipher.update(raw) + cipher.final)
  end

  test "AES callback decrypts a protocol compliant message and checks signature appid and padding" do
    encrypted = encrypt(xml)
    params = callback_params.merge(encrypt_type: "aes", msg_signature: signature(encrypted))
    assert_difference "WechatMessage.count", 1 do
      deliver("<xml><Encrypt><![CDATA[#{encrypted}]]></Encrypt></xml>", params)
      assert_response :success
    end
    [ encrypt(xml, app_id: "wrong"), encrypt(xml, bad_padding: true) ].each do |invalid|
      deliver("<xml><Encrypt>#{invalid}</Encrypt></xml>", params.merge(msg_signature: signature(invalid)))
      assert_response :forbidden
    end
    deliver("<xml><Encrypt>#{encrypted}</Encrypt></xml>", params.merge(msg_signature: "bad"))
    assert_response :forbidden
  end

  test "DTD and malformed XML rejected" do
    [ "<xml>", '<!DOCTYPE xml [<!ENTITY x SYSTEM "file:///etc/passwd">]><xml><Content>&x;</Content></xml>' ].each do |body|
      deliver(body)
      assert_response :forbidden
    end
  end
end
