class BusinessInfo
  LABELS = {
    name: "상호", representative: "대표자", address: "주소", phone: "전화",
    email: "이메일", registration_number: "사업자등록번호",
    mail_order_number: "통신판매업 신고번호", mail_order_agency: "신고기관",
    hosting_provider: "호스팅 제공자"
  }.freeze

  LABELS.each_key do |key|
    define_method(key) do
      Rails.configuration.x.business[key].to_s.dup.force_encoding(Encoding::UTF_8).scrub("").strip.presence
    end
  end

  def complete?
    missing_labels.empty?
  end

  def missing_labels
    LABELS.filter_map { |key, label| label if public_send(key).blank? }
  end

  def registration_digits
    registration_number.to_s.gsub(/[^0-9]/, "")
  end

  def effective_date
    ENV["TERMS_EFFECTIVE_DATE"].to_s.dup.force_encoding(Encoding::UTF_8).scrub("").strip.presence
  end
end
