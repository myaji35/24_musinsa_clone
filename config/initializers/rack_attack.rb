# Epic 7: Rate Limiting for UCP API
# Rack::Attack middleware configuration

class Rack::Attack
  ### Configure Cache ###
  # Use Rails cache for throttle data
  Rack::Attack.cache.store = Rails.cache

  ### Throttle UCP API requests by IP (60 requests per minute) ###
  throttle("api/v1/ucp/ip", limit: 60, period: 1.minute) do |req|
    if req.path.start_with?("/api/v1/ucp")
      req.ip
    end
  end

  ### General API throttle (300 requests per 5 minutes) ###
  throttle("api/general", limit: 300, period: 5.minutes) do |req|
    if req.path.start_with?("/api/")
      req.ip
    end
  end

  # 일반 페이지와 정적/이미지 경로는 제한하지 않고 API에만 스로틀 적용

  ### Custom response for throttled requests ###
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]
    retry_after = match_data[:period] - (now % match_data[:period])

    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s
      },
      [ {
        error: "Rate limit exceeded",
        message: "You have exceeded the API rate limit. Please try again later.",
        retry_after: retry_after
      }.to_json ]
    ]
  end

  ### Enable logging for throttled requests ###
  ActiveSupport::Notifications.subscribe("rack.attack") do |name, start, finish, request_id, payload|
    req = payload[:request]
    if req.env["rack.attack.matched"]
      Rails.logger.warn "[Rack::Attack] #{req.env['rack.attack.match_type']} blocked #{req.ip} on #{req.path}"
    end
  end
end
