require "test_helper"

class WechatHelperTest < ActionView::TestCase
  test "all message statuses have Korean badges with appropriate colors" do
    expected = {
      "received" => [ "받음", "gray" ], "received_mac" => [ "받음(맥 위챗 자동)", "gray" ],
      "received_manual" => [ "받음(붙여넣기)", "gray" ], "sent" => [ "보냄(공식계정)", "green" ],
      "sent_mac" => [ "보냄(맥 자동)", "green" ], "sent_manual" => [ "보냄(직접)", "green" ],
      "pending_manual" => [ "보내기 대기 — 복사 후 [보냈음 표시]", "orange" ],
      "awaiting_approval" => [ "승인 대기", "orange" ], "queued_mac" => [ "발송 대기", "orange" ],
      "failed" => [ "실패", "red" ], "disabled" => [ "발송 꺼짐", "gray" ], "window_closed" => [ "48시간 창 닫힘", "gray" ]
    }
    expected.each do |status, (label, color)|
      assert_equal label, wechat_status_label(status)
      assert_includes wechat_status_badge(status), "bg-#{color}-100"
      assert_includes wechat_status_badge(status), label
    end
  end

  test "text type is hidden and media types are localized" do
    assert_nil wechat_message_type("text")
    assert_equal "사진", wechat_message_type("image")
    assert_equal "음성", wechat_message_type("voice")
    assert_equal "기타", wechat_message_type("unknown")
  end

  test "timestamps use Seoul regardless of application timezone" do
    assert_equal "2026-11-18 00:05", wechat_time(Time.utc(2026, 11, 17, 15, 5))
  end
end
