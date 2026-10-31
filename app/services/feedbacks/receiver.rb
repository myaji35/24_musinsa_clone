class Feedbacks::Receiver < ApplicationService
  def initialize(params, source:, ip:, user_agent:)
    @params = params.to_h.symbolize_keys.slice(:kind, :body, :page_url, :product_id, :contact_email, :contact_consent)
    @params.delete(:product_id) unless Product.exists?(id: @params[:product_id].presence)
    @source = source
    @reporter_hash = OpenSSL::HMAC.hexdigest(
      "SHA256", Rails.application.key_generator.generate_key("feedbacks/reporter"), "#{ip}|#{Date.current}"
    )
  end

  def call
    feedback = Feedback.new(@params.merge(source: @source, reporter_hash: @reporter_hash))
    feedback.save ? success(feedback) : failure(feedback)
  end
end
