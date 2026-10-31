require "test_helper"

class Feedbacks::PurgeContactsJobTest < ActiveJob::TestCase
  test "purges old and answered contacts and keeps recent new feedback" do
    attrs = { body: "고객 의견을 전달합니다.", contact_email: "person@example.com", contact_consent: true }
    old = Feedback.create!(**attrs, created_at: 91.days.ago)
    answered = Feedback.create!(**attrs, status: "answered")
    recent = Feedback.create!(**attrs)
    assert_no_difference "Feedback.count" do
      assert_equal 2, Feedbacks::PurgeContactsJob.perform_now
    end
    [ old, answered ].each do |feedback|
      assert_nil feedback.reload.contact_email
      assert feedback.contact_purged_at
      assert_equal "고객 의견을 전달합니다.", feedback.body
    end
    assert_equal "person@example.com", recent.reload.contact_email
    assert_nil recent.contact_purged_at
    assert_equal 0, Feedbacks::PurgeContactsJob.perform_now
  end
end
