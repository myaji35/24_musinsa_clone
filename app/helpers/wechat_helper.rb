module WechatHelper
  STATUS_LABELS = {
    "received" => "받음", "received_mac" => "받음(맥 위챗 자동)", "received_manual" => "받음(붙여넣기)",
    "sent" => "보냄(공식계정)", "sent_mac" => "보냄(맥 자동)", "sent_manual" => "보냄(직접)",
    "pending_manual" => "보내기 대기 — 복사 후 [보냈음 표시]", "awaiting_approval" => "승인 대기",
    "queued_mac" => "발송 대기", "failed" => "실패", "disabled" => "발송 꺼짐", "window_closed" => "48시간 창 닫힘"
  }.freeze
  TYPE_LABELS = { "image" => "사진", "voice" => "음성", "video" => "동영상", "shortvideo" => "짧은 동영상",
                  "location" => "위치", "link" => "링크", "event" => "이벤트", "template" => "서식 메시지", "file" => "파일" }.freeze

  def wechat_status_label(status)
    STATUS_LABELS.fetch(status, "알 수 없는 상태")
  end

  def wechat_status_badge(status)
    color = case status
    when "sent", "sent_mac", "sent_manual" then "bg-green-100 text-green-800"
    when "pending_manual", "awaiting_approval", "queued_mac" then "bg-orange-100 text-orange-800"
    when "failed" then "bg-red-100 text-red-800"
    else "bg-gray-100 text-gray-800"
    end
    tag.span(wechat_status_label(status), class: "inline-block rounded-full px-3 py-1 text-sm #{color}")
  end

  def wechat_message_type(type)
    return if type == "text"
    TYPE_LABELS.fetch(type, "기타")
  end

  def wechat_time(time)
    time&.in_time_zone("Asia/Seoul")&.strftime("%Y-%m-%d %H:%M")
  end
end
