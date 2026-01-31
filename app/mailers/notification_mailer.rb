# Mailer for sending various notifications
class NotificationMailer < ApplicationMailer
  default from: ENV["DEFAULT_FROM_EMAIL"] || "noreply@jieun-fashion.com"

  # Generic notification email
  def generic_notification(to:, from: nil, subject:, body:)
    @body = body
    mail(
      to: to,
      from: from || default_params[:from],
      subject: subject
    )
  end

  # Low stock alert email
  def low_stock_alert(variant:, message:)
    @variant = variant
    @product = variant.product
    @message = message

    mail(
      to: ENV["ADMIN_EMAIL"] || "admin@jieun-fashion.com",
      subject: "[JIEUN] 재고 부족 알림: #{@product.name}"
    )
  end

  # Purchase order confirmation email to supplier
  def purchase_order_confirmation(purchase_order:, supplier:)
    @purchase_order = purchase_order
    @supplier = supplier

    mail(
      to: supplier.email,
      subject: "[JIEUN] 발주서 확인 요청 (#{purchase_order.po_number})"
    )
  end

  # Campaign notification to customer
  def campaign_notification(campaign:, customer:, message:)
    @campaign = campaign
    @customer = customer
    @message = message

    # 익명 고객이므로 실제 이메일 주소 없음
    # Slack이나 SMS로 대체하거나, 내부 Notification 테이블에만 저장
    mail(
      to: "campaigns@jieun-fashion.com", # 내부 로그용
      subject: "[JIEUN] 캠페인 알림: #{campaign.title}"
    )
  end
end
