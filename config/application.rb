require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MusinsaClone
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1
    config.x.order_record_retention_years = Integer(ENV.fetch("ORDER_RECORD_RETENTION_YEARS", "5"))
    config.x.shipping_address_retention_days = Integer(ENV.fetch("SHIPPING_ADDRESS_RETENTION_DAYS", "90"))

    config.x.privacy = {
      business_name: ENV["PRIVACY_BUSINESS_NAME"],
      officer_name: ENV["PRIVACY_OFFICER_NAME"],
      officer_contact: ENV["PRIVACY_OFFICER_CONTACT"],
      processors: ENV["PRIVACY_PROCESSORS"],
      effective_date: ENV["PRIVACY_EFFECTIVE_DATE"]
    }.transform_values { |value| value&.dup&.force_encoding(Encoding::UTF_8)&.scrub("")&.presence }

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Epic 7: Enable Rack::Attack middleware for API rate limiting
    config.middleware.use Rack::Attack
  end
end
