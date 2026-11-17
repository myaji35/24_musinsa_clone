module FeedbacksHelper
  def feedback_new_count
    @feedback_new_count ||= (current_account || Account.primary).feedbacks.where(status: "new").count
  end

  def feedback_sender(feedback)
    feedback.user&.name.presence || feedback.user&.email || "익명"
  end

  def feedback_source(feedback)
    Feedback::SOURCES.find { |_label, sources| sources.include?(feedback.source) }&.first || feedback.source
  end

  def feedback_page_link(feedback)
    url = feedback.page_url.to_s
    uri = URI.parse(url)
    safe = %w[http https].include?(uri.scheme) && uri.host.present?
    safe ||= uri.scheme.nil? && uri.host.nil? && url.start_with?("/") && !url.start_with?("//") && !url.include?("\\")
    safe ? link_to(url, url, target: "_blank", rel: "noopener noreferrer", class: "underline break-all") : url
  rescue URI::InvalidURIError
    url
  end
end
