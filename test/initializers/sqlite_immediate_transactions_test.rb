require "test_helper"
require "minitest/mock"

class SQLiteImmediateTransactionsTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "transactions begin immediately" do
    statements = []
    subscriber = ->(_name, _start, _finish, _id, payload) { statements << payload[:sql] }

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      ActiveRecord::Base.connection.transaction do
        ActiveRecord::Base.connection.execute("SELECT 1")
      end
    end

    # Rails 8 provides IMMEDIATE transactions; SQL capitalization is adapter-specific.
    assert_includes statements.map(&:downcase), "begin immediate transaction"
  end

  test "connection configuration installs a Ruby busy handler" do
    connection = ActiveRecord::Base.connection
    raw_connection = connection.raw_connection
    original_handler = raw_connection.method(:busy_handler)
    installed_handler = nil

    raw_connection.stub(:busy_handler, lambda { |&handler|
      installed_handler = handler
      original_handler.call(&handler)
    }) do
      connection.send(:configure_connection)
    end

    assert_instance_of Proc, installed_handler
    assert installed_handler.call(0)
  end
end
