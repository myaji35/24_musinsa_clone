module TrafficSourceTracking
  extend ActiveSupport::Concern

  PARAMETERS = { platform: :utm_source, campaign: :utm_campaign, video_id: :utm_content,
                 character_handle: :ch, link_code: :lc }.freeze

  included do
    before_action :capture_traffic_source
  end

  private

  def capture_traffic_source
    return unless request.get? && request.format.html?

    current_traffic_source
    return unless PARAMETERS.values.any? { |key| params.key?(key) }

    source = PARAMETERS.to_h do |key, parameter|
      value = params[parameter]
      value = value.is_a?(String) ? value.strip : ""
      value = value.downcase if key == :platform
      [ key, value.gsub(/[^A-Za-z0-9_\-.:가-힣]/, "").first(100).presence ]
    end
    session[:traffic_source] = source.merge(landed_at: Time.current.iso8601)
  end

  def current_traffic_source
    source = session[:traffic_source]
    return unless source

    source = source.to_h.symbolize_keys
    landed_at = Time.iso8601(source.fetch(:landed_at))
    return source if landed_at >= 30.days.ago && landed_at <= Time.current

    session.delete(:traffic_source)
    nil
  rescue ArgumentError, TypeError, KeyError
    session.delete(:traffic_source)
    nil
  end
end
