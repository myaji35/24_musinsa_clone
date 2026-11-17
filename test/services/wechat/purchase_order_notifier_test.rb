require "test_helper"
require "minitest/mock"

class WechatPurchaseOrderNotifierTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    accounts(:jieum).update!(wechat_channel_mode: "official")
    @po = purchase_orders(:one)
    @po.update!(status: "draft")
    @contact = WechatContact.create!(account: @po.supplier.account, supplier: @po.supplier, open_id: "po-contact")
  end

  test "submit enqueues wechat and preserves mail even if enqueue fails" do
    sign_in
    assert_enqueued_with(job: WechatPurchaseOrderJob, args: [ @po.id, users(:one).id ]) do
      Notifications::SlackNotifier.stub(:call, nil) { post submit_purchase_order_path(@po) }
    end
    assert_redirected_to purchase_order_path(@po)
    assert_equal "submitted", @po.reload.status
    @po.update!(status: "draft")
    WechatPurchaseOrderJob.stub(:perform_later, ->(*) { raise "queue unavailable" }) do
      Notifications::SlackNotifier.stub(:call, nil) { post submit_purchase_order_path(@po) }
      assert_redirected_to purchase_order_path(@po)
      assert_equal "submitted", @po.reload.status
    end
  end

  test "manual and mac app messages appear immediately after submission" do
    sign_in
    %w[manual mac_app].each do |mode|
      @po.supplier.account.update!(wechat_channel_mode: mode)
      @po.reload.update!(status: "draft")
      assert_difference "WechatMessage.count", 1 do
        assert_no_enqueued_jobs only: WechatPurchaseOrderJob do
          post submit_purchase_order_path(@po)
        end
      end
      message = @po.wechat_messages.order(:id).last
      assert_includes %w[pending_manual awaiting_approval], message.status
      follow_redirect!
      assert_response :success
      assert_select "h2", text: "위챗 발송 내역"
      assert_select "a[href=?]", wechat_path(@contact)
      assert_includes response.body, @po.order_number
    end
  end

  test "synchronous notification failure preserves submission" do
    sign_in
    @po.supplier.account.update!(wechat_channel_mode: "manual")
    Wechat::PurchaseOrderNotifier.stub(:call, ->(*) { raise "creation failed" }) do
      post submit_purchase_order_path(@po)
    end
    assert_redirected_to purchase_order_path(@po)
    assert_equal "submitted", @po.reload.status
  end

  test "notifier includes bilingual order details and full confirmation URL" do
    client = Object.new
    sent = []
    client.define_singleton_method(:send_text) { |**args| sent << args }
    Wechat::PurchaseOrderNotifier.call(@po, client: client)
    assert_equal 1, sent.size
    content = sent.first[:content]
    [ "新订单", "신규 발주", @po.order_number, "품목 수", "총수량", "납기", @po.confirmation_url ].each { |part| assert_includes content, part }
    assert_equal @contact, sent.first[:contact]
  end

  test "job failures are contained" do
    Wechat::PurchaseOrderNotifier.stub(:call, ->(*) { raise "test failure" }) do
      assert_nothing_raised { WechatPurchaseOrderJob.perform_now(@po.id) }
    end
  end

  test "resend scoped to tenant and submitted purchase orders" do
    sign_in
    post resend_wechat_purchase_order_path(@po)
    assert_redirected_to purchase_order_path(@po)
    @po.update!(status: "submitted")
    assert_enqueued_with(job: WechatPurchaseOrderJob) { post resend_wechat_purchase_order_path(@po) }
    supplier = Supplier.create!(account: accounts(:other), name: "foreign", phone: "123")
    foreign = PurchaseOrder.create!(supplier: supplier)
    get purchase_order_path(foreign)
    assert_response :not_found
    post resend_wechat_purchase_order_path(foreign)
    assert_response :not_found
  end
end
