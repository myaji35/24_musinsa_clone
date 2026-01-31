# Sentry Error Tracking Configuration
# Sign up at https://sentry.io and get your DSN

Sentry.init do |config|
  # Set your Sentry DSN here (from environment variable)
  # Get this from: https://sentry.io/settings/projects/your-project/keys/
  config.dsn = ENV["SENTRY_DSN"]

  # Enable in production and staging only
  config.enabled_environments = %w[production staging]

  # Set traces_sample_rate to 1.0 to capture 100% of transactions for performance monitoring.
  # We recommend adjusting this value in production.
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 0.1).to_f

  # Breadcrumbs configuration
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Filter sensitive data
  config.send_default_pii = false

  # Filter sensitive parameters
  config.excluded_exceptions += [
    "ActionController::RoutingError",
    "ActiveRecord::RecordNotFound"
  ]

  # Release tracking (optional)
  config.release = ENV["GIT_COMMIT_SHA"] || "development"

  # Environment
  config.environment = Rails.env

  # Performance monitoring
  config.traces_sampler = lambda do |sampling_context|
    # Sample 100% of API requests
    if sampling_context[:transaction_context][:name].start_with?("/api/")
      1.0
    else
      0.1
    end
  end
end

# Usage instructions:
# 1. Sign up at https://sentry.io
# 2. Create a new Rails project
# 3. Copy your DSN from Project Settings > Client Keys (DSN)
# 4. Set environment variable:
#    export SENTRY_DSN="https://YOUR_DSN@sentry.io/YOUR_PROJECT_ID"
# 5. Deploy and errors will be automatically tracked!
