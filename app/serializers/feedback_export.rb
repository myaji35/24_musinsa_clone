class FeedbackExport
  KEYS = %w[id created_at text source reporter_hash url kind severity].freeze

  def self.call(feedback)
    {
      "id" => feedback.id,
      "created_at" => feedback.created_at.iso8601,
      "text" => feedback.body,
      "source" => feedback.source,
      "reporter_hash" => feedback.reporter_hash,
      "url" => feedback.page_url,
      "kind" => feedback.kind,
      "severity" => nil
    }
  end
end
