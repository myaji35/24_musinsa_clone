require "test_helper"
require "minitest/mock"
require_relative "../support/seoullive_webhook_env"

class SeoulliveOrderWebhookTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include SeoulliveWebhookEnv

  setup do
    sign_in
    @order = orders(:one)
    @order.update!(status: "pending")
  end

  test "disabled or incomplete configuration never enqueues" do
    [
      { "SEOULLIVE_ORDER_WEBHOOK_ENABLED" => nil },
      { "SEOULLIVE_ORDER_WEBHOOK_ENABLED" => "false" },
      { "SEOULLIVE_ORDER_WEBHOOK_URL" => "" },
      { "SEOULLIVE_ORDER_WEBHOOK_SECRET" => nil }
    ].each do |overrides|
      with_webhook_env(overrides) do
        @order.update!(status: "pending")
        assert_no_enqueued_jobs { patch confirm_payment_admin_order_path(@order) }
        assert_redirected_to admin_orders_path
        assert_equal "paid", @order.reload.status
      end
    end
  end

  test "paid transition enqueues once and other changes do not" do
    with_webhook_env do
      assert_enqueued_jobs 1, only: SeoulliveOrderWebhookJob do
        patch confirm_payment_admin_order_path(@order)
      end
      assert_enqueued_with(job: SeoulliveOrderWebhookJob, args: [ @order.id ])
      assert_no_enqueued_jobs do
        patch confirm_payment_admin_order_path(@order)
        @order.reload.update!(quantity: 3)
        @order.update!(status: "shipped")
      end
    end
  end

  test "receiver failures cannot prevent payment confirmation" do
    with_webhook_env do
      [ :server_error, :timeout ].each do |failure|
        @order.update!(status: "pending")
        http = Object.new
        http.define_singleton_method(:request) do |_|
          raise Net::ReadTimeout if failure == :timeout
          Net::HTTPInternalServerError.new("1.1", "500", "Error")
        end
        Net::HTTP.stub(:start, ->(*, **, &block) { block.call(http) }) do
          assert_enqueued_jobs 1, only: SeoulliveOrderWebhookJob do
            patch confirm_payment_admin_order_path(@order)
          end
          assert_redirected_to admin_orders_path
          assert_equal "paid", @order.reload.status
          assert_enqueued_with(job: SeoulliveOrderWebhookJob) do
            SeoulliveOrderWebhookJob.perform_now(@order.id)
          end
        end
      end
    end
  end

  test "enqueue exceptions do not break payment confirmation" do
    with_webhook_env do
      SeoulliveOrderWebhookJob.stub(:perform_later, ->(*) { raise "queue unavailable" }) do
        patch confirm_payment_admin_order_path(@order)
        assert_redirected_to admin_orders_path
        assert_equal "paid", @order.reload.status
      end
    end
  end
end
