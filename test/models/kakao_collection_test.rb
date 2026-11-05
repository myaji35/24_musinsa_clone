require "test_helper"

class KakaoCollectionTest < ActiveSupport::TestCase
  test "token is hashed authenticated and revoked" do
    device, token = KakaoDevice.issue!(account: accounts(:other), name: "맥")
    assert_equal device, KakaoDevice.authenticate(token)
    assert_not_equal token, device.token_digest
    assert_nil KakaoDevice.authenticate("wrong")
    device.update!(revoked_at: Time.current)
    assert_nil KakaoDevice.authenticate(token)
  end

  test "shared digest vector normalization and uniqueness" do
    message = { "author" => "홍길동", "date" => "2026-11-06", "time_raw" => "오후 3:47", "body" => " 내일 30장 보내주세요 " }
    digest = KakaoMessage.message_digest("거래처", message)
    assert_equal "baaf3ba0248cf7d04f007b7e45d0c3371622b776a7056c631fed0cccc0b87a0b", digest
    assert_equal digest, KakaoMessage.message_digest("거래처", message.merge("body" => message["body"].unicode_normalize(:nfd)))
    room = accounts(:other).kakao_rooms.create!(name: "거래처")
    record = room.kakao_messages.create!(account: room.account, body: "내용", digest: digest)
    assert_not record.dup.valid?
    assert_equal 15, KakaoMessage.message_time(message["date"], message["time_raw"]).hour
    assert_nil KakaoMessage.message_time("wrong", "오후 3:47")
  end
end
