module ProductAnalysesHelper
  def won(value)
    value.nil? ? "—" : "₩#{number_with_delimiter(value.to_i)}"
  end

  def percent(value)
    value.nil? ? "—" : "#{number_with_precision(value * 100, precision: 1)}%"
  end

  def analysis_badge(status)
    colors = { "done" => "#2E844A", "failed" => "#BA0517" }
    content_tag(:span, status || "미분석", class: "rounded-full px-2 py-1 text-xs font-semibold text-white",
      style: "background-color: #{colors.fetch(status, '#706E6B')}")
  end

  def manual_assignment_badge(analysis)
    return unless analysis&.manually_assigned?

    content_tag(:span, "수동 배정", class: "rounded-full px-2 py-1 text-xs font-semibold text-white",
      style: "background-color: #0176D3")
  end
end
