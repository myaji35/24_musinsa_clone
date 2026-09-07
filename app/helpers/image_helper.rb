module ImageHelper
  # 상품 대표 이미지 소스. 첨부 > image_url 순으로 우선한다.
  def product_image_source(product)
    return product.image if product.respond_to?(:image) && product.image.attached?
    product.image_url.presence
  end

  # Generate WebP variant for Active Storage images
  def webp_image_tag(attachment, alt: "", css_class: "", lazy: true, **options)
    return "" unless attachment.attached?

    variant = attachment.variant(resize_to_limit: [ 800, 800 ], format: :webp)

    if lazy
      image_tag(
        nil,
        alt: alt,
        class: "#{css_class} lazy-image",
        data: {
          controller: "lazy-image",
          lazy_image_src_value: url_for(variant),
          src: url_for(variant)
        },
        **options
      )
    else
      image_tag(variant, alt: alt, class: css_class, **options)
    end
  end

  # Generate responsive image with WebP support
  def responsive_image_tag(src, alt: "", css_class: "", lazy: true, **options)
    return "" if src.blank?

    if lazy
      content_tag(:picture, class: "responsive-image #{css_class}") do
        concat tag.source(srcset: src, type: "image/webp")
        concat image_tag(
          nil,
          alt: alt,
          class: "lazy-image",
          data: {
            controller: "lazy-image",
            lazy_image_src_value: src,
            src: src
          },
          loading: "lazy",
          **options
        )
      end
    else
      content_tag(:picture, class: "responsive-image #{css_class}") do
        concat tag.source(srcset: src, type: "image/webp")
        concat image_tag(src, alt: alt, **options)
      end
    end
  end

  # Placeholder for images while loading
  def image_placeholder(width: 400, height: 400, text: "Loading...")
    "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='#{width}' height='#{height}'%3E%3Crect width='100%25' height='100%25' fill='%23f3f4f6'/%3E%3Ctext x='50%25' y='50%25' dominant-baseline='middle' text-anchor='middle' fill='%239ca3af' font-family='sans-serif'%3E#{text}%3C/text%3E%3C/svg%3E"
  end
end
