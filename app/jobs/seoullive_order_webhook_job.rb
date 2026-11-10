class SeoulliveOrderWebhookJob < ApplicationJob
  queue_as :default

  retry_on Seoullive::OrderWebhook::HttpError, *Seoullive::OrderWebhook::NETWORK_ERRORS,
           wait: :polynomially_longer, attempts: 5

  def perform(order_id)
    return unless Seoullive::OrderWebhook.enabled?

    order = Order.find_by(id: order_id)
    return unless order&.status == "paid"

    Seoullive::OrderWebhook.deliver(order)
  rescue *Seoullive::OrderWebhook::NETWORK_ERRORS
    Rails.logger.warn("order_id=#{order_id} code=network_error")
    raise
  end
end
