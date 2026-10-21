require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  test "body length and whitespace" do
    feedback = Feedback.new(body: "가" * 9)
    assert_not feedback.valid?
    assert_includes feedback.errors[:body], "의견은 10자 이상 적어 주세요"
    feedback.body = "  #{"가" * 10}  "
    assert feedback.valid?
    assert_equal "가" * 10, feedback.body
    feedback.body = "가" * 2001
    assert_not feedback.valid?
    assert_includes feedback.errors[:body], "의견은 2000자 이하로 적어 주세요"
  end

  test "contact requires consent and is encrypted at rest" do
    feedback = Feedback.create!(body: "고객 의견을 전달합니다.", contact_email: "person@example.com")
    assert_nil feedback.reload.contact_email
    feedback.update!(contact_consent: true, contact_email: "person@example.com")
    assert_equal "person@example.com", feedback.reload.contact_email
    raw = Feedback.connection.select_value("SELECT contact_email FROM feedbacks WHERE id=#{feedback.id}")
    assert_not_includes raw, "person@example.com"
  end

  test "inclusions email and page length are validated" do
    feedback = Feedback.new(body: "고객 의견을 전달합니다.", kind: "invalid", status: "invalid",
                            source: "invalid", page_url: "x" * 501,
                            contact_consent: true, contact_email: "invalid")
    assert_not feedback.valid?
    %i[kind status source page_url contact_email].each { |field| assert feedback.errors[field].any? }
  end

  test "purgeable includes old and resolved contacts only" do
    attrs = { body: "고객 의견을 전달합니다.", contact_consent: true, contact_email: "person@example.com" }
    old = Feedback.create!(**attrs, created_at: 91.days.ago)
    answered = Feedback.create!(**attrs, status: "answered")
    closed = Feedback.create!(**attrs, status: "closed")
    Feedback.create!(**attrs)
    Feedback.create!(**attrs, created_at: 91.days.ago, contact_purged_at: Time.current)
    Feedback.create!(body: "연락처가 없는 의견입니다.", created_at: 91.days.ago)
    assert_equal [ old.id, answered.id, closed.id ].sort, Feedback.contact_purgeable.pluck(:id).sort
  end
end
