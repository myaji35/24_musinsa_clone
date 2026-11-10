module SeoulliveWebhookEnv
  def with_webhook_env(overrides = {})
    values = {
      "SEOULLIVE_ORDER_WEBHOOK_ENABLED" => "true",
      "SEOULLIVE_ORDER_WEBHOOK_URL" => "https://example.invalid/webhook",
      "SEOULLIVE_ORDER_WEBHOOK_SECRET" => "test-secret"
    }.merge(overrides)
    previous = values.keys.to_h { |key| [ key, ENV[key] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
