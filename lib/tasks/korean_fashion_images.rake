# 한국 여성복 Unsplash 이미지로 업데이트
namespace :images do
  desc "Update products with Korean women's fashion images from Unsplash"
  task korean_fashion: :environment do
    puts "🇰🇷 한국 여성복 이미지 업데이트 시작..."

    # 한국 여성복 스타일 Unsplash 이미지 URL
    korean_fashion_images = [
      # 미니멀 여성복
      "https://images.unsplash.com/photo-1539008835657-9e8e9680c956?w=400&h=500&fit=crop", # 화이트 셔츠
      "https://images.unsplash.com/photo-1591369822096-ffd140ec948f?w=400&h=500&fit=crop", # 베이직 블랙 원피스
      "https://images.unsplash.com/photo-1594633313593-bab3825d0caf?w=400&h=500&fit=crop", # 화이트 티셔츠

      # 캐주얼 아우터
      "https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=400&h=500&fit=crop", # 데님 재킷
      "https://images.unsplash.com/photo-1578932750294-f5075e85f44a?w=400&h=500&fit=crop", # 트렌치 코트
      "https://images.unsplash.com/photo-1551028719-00167b16eac5?w=400&h=500&fit=crop", # 롱 코트

      # 니트/가디건
      "https://images.unsplash.com/photo-1576566588028-4147f3842f27?w=400&h=500&fit=crop", # 베이지 니트
      "https://images.unsplash.com/photo-1620799140408-edc6dcb6d633?w=400&h=500&fit=crop", # 화이트 가디건
      "https://images.unsplash.com/photo-1617922001439-4a2e6562f328?w=400&h=500&fit=crop", # 크림 스웨터

      # 원피스/스커트
      "https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=400&h=500&fit=crop", # 플리츠 스커트
      "https://images.unsplash.com/photo-1612423284934-2850a4ea6b0f?w=400&h=500&fit=crop", # 시폰 원피스
      "https://images.unsplash.com/photo-1585487000160-6ebcfceb0d03?w=400&h=500&fit=crop", # 블랙 원피스

      # 블라우스/셔츠
      "https://images.unsplash.com/photo-1564584217132-2271feaeb3c5?w=400&h=500&fit=crop", # 스트라이프 셔츠
      "https://images.unsplash.com/photo-1624206112918-f140f087f9b5?w=400&h=500&fit=crop", # 화이트 블라우스
      "https://images.unsplash.com/photo-1618932260643-eee4a2f652a6?w=400&h=500&fit=crop", # 실크 블라우스

      # 팬츠
      "https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=400&h=500&fit=crop", # 와이드 팬츠
      "https://images.unsplash.com/photo-1624378439575-d8705ad7ae80?w=400&h=500&fit=crop", # 슬랙스
      "https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=400&h=500&fit=crop", # 린넨 팬츠

      # 악세서리/스타일링
      "https://images.unsplash.com/photo-1591085686350-798c0f9faa7f?w=400&h=500&fit=crop", # 미니멀 백
      "https://images.unsplash.com/photo-1606760227091-3dd870d97f1d?w=400&h=500&fit=crop", # 가죽 백

      # 추가 여성복
      "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=400&h=500&fit=crop", # 베이지 코트
      "https://images.unsplash.com/photo-1558769132-cb1aea28c2e8?w=400&h=500&fit=crop", # 블랙 재킷
      "https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=400&h=500&fit=crop", # 화이트 셔츠
      "https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=400&h=500&fit=crop", # 레이어드 룩
      "https://images.unsplash.com/photo-1551028719-00167b16eac5?w=400&h=500&fit=crop", # 캐시미어 코트
      "https://images.unsplash.com/photo-1509631179647-0177331693ae?w=400&h=500&fit=crop", # 미니멀 드레스
      "https://images.unsplash.com/photo-1558769132-cb1aea28e2fe?w=400&h=500&fit=crop", # 블랙 톱
      "https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=400&h=500&fit=crop", # 크림 니트
      "https://images.unsplash.com/photo-1591369822096-ffd140ec948e?w=400&h=500&fit=crop", # 네이비 원피스
      "https://images.unsplash.com/photo-1585487000143-66b1a9c44dd5?w=400&h=500&fit=crop"  # 베이지 점프수트
    ]

    updated_count = 0

    Product.find_each.with_index do |product, index|
      # 순환하며 이미지 할당
      image_url = korean_fashion_images[index % korean_fashion_images.length]

      if product.update(image_url: image_url)
        updated_count += 1
        puts "  ✅ #{product.name}: #{image_url}"
      else
        puts "  ❌ #{product.name}: 업데이트 실패"
      end
    end

    puts "\n🎉 완료! #{updated_count}개 상품 이미지 업데이트됨"
  end

  desc "Preview Korean fashion image URLs"
  task preview_korean: :environment do
    puts "🖼️  한국 여성복 이미지 미리보기 URL:"
    puts "-" * 80

    korean_fashion_images = [
      "https://images.unsplash.com/photo-1539008835657-9e8e9680c956?w=400&h=500&fit=crop",
      "https://images.unsplash.com/photo-1591369822096-ffd140ec948f?w=400&h=500&fit=crop",
      "https://images.unsplash.com/photo-1594633313593-bab3825d0caf?w=400&h=500&fit=crop"
    ]

    korean_fashion_images.first(5).each_with_index do |url, i|
      puts "#{i + 1}. #{url}"
    end

    puts "\n총 #{korean_fashion_images.count}개 이미지 준비됨"
  end
end
