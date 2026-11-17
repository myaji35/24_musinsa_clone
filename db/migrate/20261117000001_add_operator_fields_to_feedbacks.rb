class AddOperatorFieldsToFeedbacks < ActiveRecord::Migration[8.1]
  def up
    add_reference :feedbacks, :account, foreign_key: true
    add_reference :feedbacks, :user, foreign_key: { on_delete: :nullify }
    add_column :feedbacks, :manual_chapter, :integer
    add_column :feedbacks, :handling_note, :text
    execute <<~SQL
      UPDATE feedbacks SET account_id = (SELECT id FROM accounts WHERE slug = 'jieum')
    SQL
    change_column_null :feedbacks, :account_id, false
  end

  def down
    remove_column :feedbacks, :handling_note
    remove_column :feedbacks, :manual_chapter
    remove_reference :feedbacks, :user, foreign_key: true
    remove_reference :feedbacks, :account, foreign_key: true
  end
end
