# Free-form feedback and context may themselves contain personal information.
Rails.application.config.filter_parameters += [ :feedback ]

module FeedbackRequestPrivacy
  private

  def started_request_message(request)
    return super unless request.path == "/feedbacks" || request.path == "/feedbacks/new"

    "Started #{request.request_method} #{request.path.inspect} for [FILTERED] at #{Time.current}"
  end
end

Rails::Rack::Logger.prepend(FeedbackRequestPrivacy)
