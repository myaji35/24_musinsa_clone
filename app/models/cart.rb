class Cart
  Item = Struct.new(:variant, :quantity, keyword_init: true) do
    def product
      variant.product
    end

    def line_total
      product.price.to_i * quantity
    end
  end

  def initialize(contents = {})
    @contents = {}
    contents.to_h.each do |id, quantity|
      @contents[id.to_s] = clamp(quantity) if id.to_s.match?(/\A[0-9]+\z/)
    end
    valid_ids = Variant.where(id: @contents.keys).pluck(:id).map(&:to_s)
    @contents.select! { |id, _| valid_ids.include?(id) }
  end

  def items
    Variant.includes(:product).where(id: @contents.keys).map do |variant|
      Item.new(variant: variant, quantity: @contents.fetch(variant.id.to_s))
    end
  end

  def total
    items.sum(&:line_total)
  end

  def count
    @contents.values.sum
  end

  def add(variant_id, quantity = 1)
    update(variant_id, @contents.fetch(variant_id.to_s, 0) + clamp(quantity))
  end

  def update(variant_id, quantity)
    @contents[variant_id.to_s] = clamp(quantity) if Variant.exists?(id: variant_id)
  end

  def remove(variant_id)
    @contents.delete(variant_id.to_s)
  end

  def to_h
    @contents.dup
  end

  private

  def clamp(quantity)
    quantity.to_s.to_i.clamp(1, 99)
  end
end
