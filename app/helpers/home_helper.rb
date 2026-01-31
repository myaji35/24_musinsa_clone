module HomeHelper
  # 29cm 스타일 큐레이션 섹션 타이틀
  def mood_to_title(mood)
    titles = {
      "minimal" => "미니멀 컬렉션",
      "casual" => "캐주얼 에브리데이",
      "delicate" => "섬세한 감성",
      "vintage" => "빈티지 무드",
      "modern" => "모던 클래식"
    }
    titles[mood] || mood.to_s.capitalize
  end

  # 29cm 스타일 큐레이션 섹션 설명
  def mood_to_description(mood)
    descriptions = {
      "minimal" => "심플하지만 세련된, 절제된 아름다움",
      "casual" => "편안하고 자연스러운 일상 스타일",
      "delicate" => "부드럽고 우아한 여성스러운 매력",
      "vintage" => "시간이 만들어낸 특별한 감성",
      "modern" => "현대적이고 세련된 도시적 감각"
    }
    descriptions[mood] || "당신을 위한 특별한 선택"
  end
end
