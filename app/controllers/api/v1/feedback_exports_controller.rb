module Api
  module V1
    class FeedbackExportsController < ApplicationController
      skip_before_action :require_admin
      skip_before_action :verify_authenticity_token
      before_action :authenticate_export_key

      def index
        since = params[:since].to_i
        limit = params[:limit].to_i
        limit = 100 if limit <= 0
        feedbacks = Feedback.where("id > ?", since).order(:id).limit([ limit, 200 ].min).to_a
        render json: {
          status: "success", count: feedbacks.size,
          next_since: feedbacks.last&.id || since,
          feedbacks: feedbacks.map { |feedback| FeedbackExport.call(feedback) }
        }
      end

      def ack
        updated = []
        not_found = []
        ack_items.first(200).each do |item|
          feedback = Feedback.find_by(id: item[:id])
          unless feedback
            not_found << item[:id]
            next
          end

          flags = Array(item[:flags]).first(20).map { |flag| flag.to_s.first(50) }
          attributes = {
            factory_feedback_id: item[:factory_feedback_id]&.to_s&.first(100),
            factory_issue_id: item[:factory_issue_id]&.to_s&.first(100),
            factory_action: item[:action]&.to_s&.first(100),
            factory_flags: flags, forwarded_at: Time.current
          }
          if %w[new forwarded needs_review].include?(feedback.status)
            attributes[:status] = flags.empty? ? "forwarded" : "needs_review"
          end
          feedback.update!(attributes)
          updated << feedback.id
        end
        render json: { status: "success", updated: updated, not_found: not_found }
      end

      private

      def ack_items
        params.permit(items: [ :id, :factory_feedback_id, :factory_issue_id, :action, { flags: [] } ])
          .fetch(:items, [])
      end

      def authenticate_export_key
        expected = ENV["FEEDBACK_EXPORT_KEY"]
        if expected.blank?
          Rails.logger.error "FEEDBACK_EXPORT_KEY 미설정"
          render json: { status: "error", message: "API가 구성되지 않았습니다." }, status: :service_unavailable
          return
        end
        provided = request.headers["X-API-Key"]
        unless provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided.to_s, expected)
          render json: { status: "error", message: "유효하지 않은 API 키입니다." }, status: :unauthorized
        end
      end
    end
  end
end
