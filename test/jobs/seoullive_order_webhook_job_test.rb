require "test_helper"
require "minitest/mock"
require_relative "../support/seoullive_webhook_env"

class SeoulliveOrderWebhookJobTest < ActiveJob::TestCase
  include SeoulliveWebhookEnv

  test "disabled missing and unpaid orders do not deliver" do
    calls = []
    Seoullive::OrderWebhook.stub(:deliver, ->(*) { calls << true }) do
      with_webhook_env("SEOULLIVE_ORDER_WEBHOOK_ENABLED" => nil) { SeoulliveOrderWebhookJob.perform_now(orders(:one).id) }
      with_webhook_env do
        SeoulliveOrderWebhookJob.perform_now(-1)
        SeoulliveOrderWebhookJob.perform_now(orders(:two).id)
      end
    end
    assert_empty calls
  end

  test "paid order is delivered" do
    with_webhook_env do
      delivered = []
      Seoullive::OrderWebhook.stub(:deliver, ->(order) { delivered << order.id }) do
        SeoulliveOrderWebhookJob.perform_now(orders(:one).id)
      end
      assert_equal [ orders(:one).id ], delivered
    end
  end

  test "HTTP and network errors retry with a five attempt limit" do
    with_webhook_env do
      [ Seoullive::OrderWebhook::HttpError, Net::OpenTimeout, Net::ReadTimeout ].each do |error|
        Seoullive::OrderWebhook.stub(:deliver, ->(*) { raise error }) do
          assert_enqueued_with(job: SeoulliveOrderWebhookJob, args: [ orders(:one).id ]) do
            SeoulliveOrderWebhookJob.perform_now(orders(:one).id)
          end
          job = SeoulliveOrderWebhookJob.new(orders(:one).id)
          4.times { job.perform_now }
          assert_no_enqueued_jobs do
            assert_raises(error) { job.perform_now }
          end
        end
      end
    end
  end
end
