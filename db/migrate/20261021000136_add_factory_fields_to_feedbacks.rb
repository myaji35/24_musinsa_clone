class AddFactoryFieldsToFeedbacks < ActiveRecord::Migration[8.1]
  def change
    add_column :feedbacks, :factory_feedback_id, :string
    add_column :feedbacks, :factory_issue_id, :string
    add_column :feedbacks, :factory_action, :string
    add_column :feedbacks, :factory_flags, :text
    add_column :feedbacks, :forwarded_at, :datetime
  end
end
