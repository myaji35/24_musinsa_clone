# frozen_string_literal: true

# Rails 7.2의 DEFERRED 트랜잭션은 WAL에서 읽기 잠금을 쓰기 잠금으로 승격할 때
# 즉시 BUSY가 날 수 있고, 기본 busy_timeout은 대기하는 동안 GVL을 잡는다.
# Rails 8 이상으로 업그레이드하면 기본 어댑터가 이를 처리하므로 이 파일을 제거한다.
if ActiveRecord.version < Gem::Version.new("8.0")
  module SQLiteImmediateTransactions
    def begin_db_transaction # :nodoc:
      log("begin immediate transaction", "TRANSACTION") do
        with_raw_connection(allow_retry: true, materialize_transactions: false) do |connection|
          result = connection.transaction(:immediate)
          verified!
          result
        end
      end
    end

    private

      def configure_connection
        super

        return unless @config[:timeout]

        timeout = self.class.type_cast_config_to_integer(@config[:timeout])
        deadline = nil

        @raw_connection.busy_handler do |count|
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          deadline = now + timeout.fdiv(1000) if count.zero?
          remaining = deadline - now

          if remaining.positive?
            sleep([ remaining, 0.001 ].min)
            true
          else
            false
          end
        end
      end
  end

  ActiveSupport.on_load(:active_record_sqlite3adapter) do
    prepend SQLiteImmediateTransactions
  end
end
