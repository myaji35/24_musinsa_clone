# Mockup image generator
namespace :mockup do
  desc "Generate SVG mockup images for products"
  task generate_images: :environment do
    require "fileutils"

    output_dir = Rails.root.join("public", "images", "products")
    FileUtils.mkdir_p(output_dir)

    categories = {
      "Outer" => { bg: "#E8D5C4", text: "OUTER" },
      "Top" => { bg: "#D4E8E4", text: "TOP" },
      "Bottom" => { bg: "#E4D4E8", text: "BOTTOM" },
      "One-piece" => { bg: "#E8E4D4", text: "DRESS" },
      "Skirt" => { bg: "#D4D8E8", text: "SKIRT" },
      "Bag" => { bg: "#E8D4D8", text: "BAG" },
      "Shoes" => { bg: "#D8E8D4", text: "SHOES" }
    }

    moods = [ "minimal", "casual", "delicate", "vintage", "modern" ]

    # Generate 20 unique mockup images
    20.times do |i|
      category = categories.keys.sample
      mood = moods.sample
      color = categories[category]

      filename = "product_#{i + 1}.svg"
      filepath = output_dir.join(filename)

      svg_content = generate_svg(i + 1, category, mood, color)
      File.write(filepath, svg_content)

      puts "✓ Generated: #{filename} (#{category}, #{mood})"
    end

    puts "\n🎉 Generated 20 mockup images in public/images/products/"
  end

  desc "Update all products with mockup images"
  task update_products: :environment do
    Product.find_each.with_index do |product, index|
      image_num = (index % 20) + 1
      new_url = "/images/products/product_#{image_num}.svg"

      product.update_column(:image_url, new_url)
      puts "✓ Updated Product ##{product.id}: #{product.name} → #{new_url}"
    end

    puts "\n🎉 Updated #{Product.count} products with mockup images!"
  end

  def generate_svg(num, category, mood, color)
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 500">
        <!-- Background -->
        <rect width="400" height="500" fill="#{color[:bg]}"/>

        <!-- Fashion illustration placeholder -->
        <circle cx="200" cy="180" r="60" fill="white" opacity="0.3"/>
        <rect x="160" y="240" width="80" height="120" rx="10" fill="white" opacity="0.3"/>

        <!-- Category badge -->
        <rect x="20" y="20" width="100" height="30" rx="15" fill="white" opacity="0.8"/>
        <text x="70" y="40" font-family="Arial, sans-serif" font-size="12" font-weight="bold"
              text-anchor="middle" fill="#333">#{color[:text]}</text>

        <!-- Mood tag -->
        <rect x="280" y="20" width="100" height="24" rx="12" fill="black" opacity="0.7"/>
        <text x="330" y="37" font-family="Arial, sans-serif" font-size="11" font-weight="500"
              text-anchor="middle" fill="white">#{mood.upcase}</text>

        <!-- Product number -->
        <text x="200" y="450" font-family="Arial, sans-serif" font-size="48" font-weight="bold"
              text-anchor="middle" fill="white" opacity="0.6">#{num.to_s.rjust(2, '0')}</text>

        <!-- Decorative elements -->
        <circle cx="350" cy="450" r="30" fill="white" opacity="0.2"/>
        <circle cx="50" cy="450" r="20" fill="white" opacity="0.2"/>

        <!-- JIEUN branding -->
        <text x="200" y="485" font-family="Arial, sans-serif" font-size="10" font-weight="300"
              text-anchor="middle" fill="#666" opacity="0.8">JIEUN FASHION</text>
      </svg>
    SVG
  end
end
