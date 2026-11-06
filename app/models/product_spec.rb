class ProductSpec
  include ActiveModel::Validations

  MEASUREMENT_TEMPLATES = {
    "아우터" => %w[총장 어깨너비 가슴단면 소매길이 밑단단면],
    "상의" => %w[총장 어깨너비 가슴단면 소매길이],
    "원피스" => %w[총장 어깨너비 가슴단면 허리단면 소매길이],
    "바지" => %w[총장 허리단면 엉덩이단면 허벅지단면 밑위 밑단단면],
    "스커트" => %w[총장 허리단면 엉덩이단면 밑단단면],
    "가방" => %w[가로 세로 폭 끈길이], "신발" => %w[발길이 굽높이 발볼],
    "액세서리" => %w[가로 세로]
  }.freeze
  FIT_OPTIONS = {
    "핏" => %w[슬림 레귤러 세미오버 오버], "두께감" => %w[얇음 보통 두꺼움],
    "신축성" => %w[없음 약간 좋음], "비침" => %w[없음 약간 있음],
    "안감 유무" => %w[있음 없음 부분], "계절" => %w[봄 여름 가을 겨울]
  }.freeze
  MATERIAL_FIELDS = %w[겉감 안감 충전재 배색].freeze

  attr_reader :product
  validate :validate_values

  def initialize(product)
    @product = product
  end

  def data
    product.spec.is_a?(Hash) ? product.spec : {}
  end

  def group(key)
    data[key].is_a?(Hash) ? data[key] : {}
  end

  def value(value)
    text = value.to_s.strip
    text.start_with?("TODO:") ? "" : text
  end

  def measurement(size, item)
    row = group("measurements")[size]
    value(row.is_a?(Hash) ? row[item] : nil)
  end

  def material(field)
    value(group("material")[field])
  end

  def fit(field)
    raw = group("fit")[field]
    field == "계절" ? Array(raw).map { |entry| value(entry) }.compact_blank : value(raw)
  end

  def colors
    product.variants.reject(&:marked_for_destruction?).map(&:color).map { |entry| value(entry) }.compact_blank.uniq
  end

  def sizes
    product.variants.reject(&:marked_for_destruction?).map(&:size).map { |entry| value(entry) }.compact_blank.uniq.sort_by { |size| Product::SIZE_ORDER.index(size.upcase) || Product::SIZE_ORDER.length }
  end

  def measurement_items
    category = product.category.to_s.downcase.gsub(/\s+/, "")
    category = { "outer" => "아우터", "코트" => "아우터", "패딩" => "아우터", "one-piece" => "원피스" }.fetch(category, category)
    MEASUREMENT_TEMPLATES.fetch(category, MEASUREMENT_TEMPLATES["액세서리"])
  end

  def visible_measurement_items
    measurement_items.select { |item| sizes.any? { |size| measurement(size, item).present? } }
  end

  def measurements?
    visible_measurement_items.any?
  end

  def required_items
    sizes.flat_map { |size| measurement_items.map { |item| [ "실측 · #{size} #{item}", measurement(size, item).present? ] } } +
      [ [ "소재 · 겉감", material("겉감").present? ] ] +
      FIT_OPTIONS.keys.map { |field| [ "핏 · #{field}", fit(field).present? ] }
  end

  def missing_items
    required_items.reject(&:last).map(&:first)
  end

  def completion_rate
    ((required_items.count(&:last).to_f / required_items.size) * 100).round
  end

  def complete?
    missing_items.empty?
  end

  def fill_info_notice
    notice = (product.info_notice || {}).dup
    materials = %w[겉감 안감 충전재].select { |field| material(field).present? }
    fabric = if material("겉감").present?
      materials.size == 1 ? material("겉감") : materials.map { |field| "#{field}: #{material(field)}" }.join(", ")
    end
    { "소재" => fabric, "색상" => colors.join("/"), "치수" => sizes.join(" / ") }.each do |field, entry|
      notice[field] = entry if notice[field].blank? && entry.present?
    end
    product.info_notice = notice
  end

  private

  def topic_particle(word)
    code = word.to_s[-1]&.ord
    return "은(는)" unless code && code.between?(0xAC00, 0xD7A3)

    (code - 0xAC00) % 28 != 0 ? "은" : "는"
  end

  def validate_values
    group("measurements").each do |size, row|
      next unless row.is_a?(Hash)
      row.each do |item, raw|
        text = value(raw)
        next if text.blank? || (text.match?(/\A\d+(?:\.\d)?\z/) && text.to_f > 0 && text.to_f <= 300)
        errors.add(:base, "#{size} 사이즈 #{item}#{topic_particle(item)} 0보다 크고 300 이하인 숫자(cm)로 입력해 주세요")
      end
    end
    weight = value(data["weight_g"])
    unless weight.blank? || (weight.match?(/\A\d+\z/) && weight.to_i.between?(1, 20_000))
      errors.add(:base, "무게는 1부터 20000까지의 정수(g)로 입력해 주세요")
    end
    MATERIAL_FIELDS.each do |field|
      errors.add(:base, "소재 #{field}#{topic_particle(field)} 100자 이하로 입력해 주세요") if material(field).length > 100
    end
    errors.add(:base, "메모는 300자 이하로 입력해 주세요") if value(data["note"]).length > 300
    group("fit").each do |field, raw|
      choices = FIT_OPTIONS[field]
      entries = Array(raw).map { |entry| value(entry) }.compact_blank
      unless choices && (field == "계절" || !raw.is_a?(Array)) && (entries - choices).empty?
        errors.add(:base, "#{field}#{topic_particle(field)} 정해진 보기에서 선택해 주세요")
      end
    end
  end
end
