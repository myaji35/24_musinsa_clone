# Run: bin/rails runner docs/manual/build/seed_demo.rb
require "json"
require "fileutils"
abort "매뉴얼 예시는 development 전용입니다" unless Rails.env.development?

account = Account.primary # ApplicationController와 같은 기본 계정 결정 방식
abort "기본 계정은 mac_app이어야 합니다 (현재값을 변경하지 않습니다)" unless account.wechat_channel_mode == "mac_app"
abort "WECHAT_MAC_AUTO_SEND를 해제한 뒤 실행하세요" if Wechat::Config.mac_auto_send?
admin = User.find_by!(email: "admin@jieun.test")
abort "관리자가 기본 계정 소속이 아닙니다" if admin.account_id && admin.account_id != account.id
variants = Variant.includes(:product).order(:id).limit(3).to_a
abort "기존 상품 옵션이 최소 2개 필요합니다" if variants.size < 2
# Intake의 모델 콜백은 유지하되 예시 데이터 때문에 외부 알림 작업을 큐에 넣지 않는다.
# runner 전용 프로세스에서만 적용된다.
class ManualDemoQueueAdapter < ActiveJob::QueueAdapters::AbstractAdapter
  def enqueue(job)
    Rails.logger.info("manual demo: skipped job #{job.class.name}")
  end

  def enqueue_at(job, _timestamp)
    enqueue(job)
  end
end
ActiveJob::Base.queue_adapter = ManualDemoQueueAdapter.new
ids = {}

ActiveRecord::Base.transaction do
  supplier = account.suppliers.find_or_initialize_by(name: "광저우 화련 복장 (매뉴얼 예시)")
  supplier.update!(kind: "purchase", contact_person: "陈经理", phone: "+86 20 0000 0000",
                   payment_terms: "선금 30%·잔금 70%", active: true)
  contact = account.wechat_contacts.find_or_initialize_by(wechat_display_name: "陈经理-华莲服装")
  contact.update!(supplier: supplier)
  ids.merge!(account_id: account.id, supplier_id: supplier.id, contact_id: contact.id, admin_id: admin.id)

  %w[draft submitted confirmed].each do |role|
    po = supplier.purchase_orders.find_or_initialize_by(notes: "매뉴얼 예시 / #{role}")
    if po.new_record?
      po.status = "draft"
      variants.each_with_index do |variant, index|
        po.purchase_order_items.build(variant: variant, quantity: [ 50, 80, 120 ][index],
                                     unit_price: variant.product.price.presence || 10_000)
      end
    end
    abort "예시 발주 상태가 변경되었습니다: #{po.id}. 기존 예시를 확인하세요" unless po.status.in?([ "draft", role ])
    po.expected_delivery_date = Date.current + 21
    po.save!
    if role == "submitted"
      raise "발주 제출 실패" if po.status == "draft" && !po.submit!
      unless po.wechat_messages.where(wechat_contact: contact, status: "pending_manual").exists?
        # 동기 호출: 메일·Slack·외부 발송 없이 실제 통보문 생성 로직 사용.
        Wechat::PurchaseOrderNotifier.call(po, sent_by: admin)
      end
      # 이미 생성된 예시 통보문도 현재 앱 URL 설정을 반영한다.
      po.wechat_messages.where(wechat_contact: contact, status: "pending_manual").each do |message|
        message.update!(content: message.content.lines.tap { |lines| lines[-1] = po.confirmation_url }.join)
      end
      # 처리 이력과 대기 버튼을 한 화면에서 보여 주는 별도의 수동 발송 예시.
      sent = po.wechat_messages.find_or_initialize_by(wechat_contact: contact, status: "sent_manual")
      if sent.new_record?
        sent.assign_attributes(account: account, direction: "out", msg_type: "text", sent_by: admin,
                               content: "订单已发送，请确认。 / 발주 내용을 보냈습니다. 확인 부탁드립니다.",
                               processed_by: admin, processed_at: 40.minutes.ago, created_at: 40.minutes.ago)
        sent.save!
      end
      ids[:sent_message_id] = sent.id
    end
    if role == "confirmed" && po.status == "draft"
      raise "발주 제출 실패" unless po.submit!
      raise "발주 확정 실패" unless po.confirm!
    end
    ids["#{role}_po_id"] = po.id
  end

  [ "收到，我们确认一下面料，明天回复您。", "面料已确认，预计12月8日出货。" ].each_with_index do |content, index|
    message = contact.wechat_messages.find_or_initialize_by(direction: "in", content: content)
    if message.new_record?
      at = (30 - index * 10).minutes.ago
      message.update!(account: account, msg_type: "text", status: "received_mac", received_at: at, created_at: at)
    end
    ids["received_message_#{index + 1}_id"] = message.id
  end
  contact.update!(last_inbound_at: contact.wechat_messages.where(direction: "in").maximum(:created_at))

  order = Order.pending.order(:id).first
  unless order
    variant = Variant.joins(:product).where("variants.stock > 0 AND products.price > 0").order(:id).first
    raise "입금 대기 예시 주문에는 가격·재고가 있는 기존 옵션이 필요합니다" unless variant
    result = Orders::Intake.call(items: [ { variant_id: variant.id, quantity: 1 } ],
      address: { recipient_name: "예시 고객", phone: "01000000000", postal_code: "00000",
                 address1: "예시 고객", address2: "예시 고객", country_code: "KR" }, save_consent: false)
    raise "주문 생성 실패: #{result.errors.join(', ')}" unless result.success?
    order = result.orders.first
  end
  ids[:pending_order_id] = order.id
  claim = supplier.supplier_claims.find_or_initialize_by(description: "매뉴얼 예시: 봉제 불량 2개 확인 요청")
  claim.assign_attributes(claim_type: "defective", status: "open", quantity: 2,
                          purchase_order_id: ids["submitted_po_id"], created_by_user: admin)
  claim.save! # 다른 거래처 상품을 연결하면 모델 규칙 위반이므로 variant는 생략
  ids[:claim_id] = claim.id
end

out = File.join(__dir__, "out")
FileUtils.mkdir_p(out)
File.write(File.join(out, "demo_ids.json"), JSON.pretty_generate(ids) + "\n")
puts JSON.pretty_generate(ids)
