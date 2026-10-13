module ApplicationHelper
  def seoul_datetime(value)
    value.in_time_zone("Asia/Seoul").strftime("%Y-%m-%d %H:%M")
  end
end
