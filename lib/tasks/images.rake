# Real fashion images from Unsplash
namespace :images do
  desc "Update products with real fashion images from Unsplash"
  task update_with_unsplash: :environment do
    # Unsplash fashion images (public domain, 400x500 optimized)
    fashion_images = [
      "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=400&h=500&fit=crop", # Fashion model
      "https://images.unsplash.com/photo-1539533018447-63fcce2678e3?w=400&h=500&fit=crop", # White dress
      "https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=400&h=500&fit=crop", # Coat
      "https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400&h=500&fit=crop", # Shopping
      "https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=400&h=500&fit=crop", # Fashion accessories
      "https://images.unsplash.com/photo-1558769132-cb1aea1f5a51?w=400&h=500&fit=crop", # Casual wear
      "https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=400&h=500&fit=crop", # Minimal style
      "https://images.unsplash.com/photo-1544441893-675973e31985?w=400&h=500&fit=crop", # Black outfit
      "https://images.unsplash.com/photo-1525507119028-ed4c629a60a3?w=400&h=500&fit=crop", # Bag
      "https://images.unsplash.com/photo-1551028719-00167b16eac5?w=400&h=500&fit=crop", # Shoes
      "https://images.unsplash.com/photo-1520975916090-3105956dac38?w=400&h=500&fit=crop", # Red dress
      "https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=400&h=500&fit=crop", # Sweater
      "https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=400&h=500&fit=crop", # One-piece
      "https://images.unsplash.com/photo-1581044777550-4cfa60707c03?w=400&h=500&fit=crop", # Pants
      "https://images.unsplash.com/photo-1562157873-818bc0726f68?w=400&h=500&fit=crop", # Skirt
      "https://images.unsplash.com/photo-1568252542512-9fe8fe9c87bb?w=400&h=500&fit=crop", # Outer
      "https://images.unsplash.com/photo-1503342217505-b0a15ec3261c?w=400&h=500&fit=crop", # Modern style
      "https://images.unsplash.com/photo-1567401893414-76b7b1e5a7a5?w=400&h=500&fit=crop", # Delicate
      "https://images.unsplash.com/photo-1509631179647-0177331693ae?w=400&h=500&fit=crop", # Casual top
      "https://images.unsplash.com/photo-1617922001439-4a2e6562f328?w=400&h=500&fit=crop"  # Vintage style
    ]

    Product.find_each.with_index do |product, index|
      # Cycle through images
      image_url = fashion_images[index % fashion_images.length]
      product.update_column(:image_url, image_url)

      puts "✓ Updated Product ##{product.id}: #{product.name}"
      puts "  → #{image_url}"
    end

    puts "\n🎉 Updated #{Product.count} products with Unsplash fashion images!"
    puts "📸 Images are from Unsplash (free to use)"
  end
end
