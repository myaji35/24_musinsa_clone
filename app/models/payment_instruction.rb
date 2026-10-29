class PaymentInstruction
  def bank
    env_value("PAYOUT_BANK")
  end

  def account
    env_value("PAYOUT_ACCOUNT")
  end

  def holder
    env_value("PAYOUT_HOLDER")
  end

  def contact
    env_value("PAYOUT_CONTACT")
  end

  def ready?
    [ bank, account, holder ].all?(&:present?)
  end

  def due_days
    value = env_value("PAYOUT_DUE_DAYS")
    value.match?(/\A[0-9]+\z/) ? value.to_i : 3
  end

  def due_on(order_time)
    order_time.in_time_zone("Asia/Seoul").to_date + due_days
  end

  private

  # 로캘이 UTF-8 이 아닌 프로세스에서는 ENV 값이 ASCII-8BIT 로 들어와 한글 화면 렌더가 깨진다
  def env_value(key)
    ENV[key].to_s.dup.force_encoding(Encoding::UTF_8).scrub("").strip
  end
end
