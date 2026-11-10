require "application_system_test_case"

class ProductsTest < ApplicationSystemTestCase
  # 시나리오 6: 상품 목록 페이지
  test "상품 목록 페이지가 정상 작동하는가" do
    visit products_path

    # 상품 카드가 표시되는가
    assert_selector ".grid"

    # 가격이 표시되는가
    assert_selector ".price", minimum: 1
  end

  # 시나리오 7: 상품 상세 페이지
  test "상품 상세 페이지가 정상 작동하는가" do
    product = products(:one)
    visit product_path(product)

    # 상품명이 표시되는가
    assert_text product.name

    # 가격이 표시되는가
    assert_text "₩ #{product.price.to_i.to_fs(:delimited)}"
  end

  test "상품 옵션은 모바일과 데스크톱에서 영역 안에 가로로 배치된다" do
    product = products(:one)
    product.variants.create!(color: variants(:one).color, size: "S", stock: 5)
    product.variants.create!(color: variants(:one).color, size: "L", stock: 5)
    browser = page.driver.browser

    [ [ 375, 812 ], [ 1440, 900 ] ].each do |width, height|
      browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: width < 768)
      visit product_path(product)
      assert_selector '[data-testid="variant-picker"] label > span', count: 3

      layout = page.evaluate_script(<<~JS)
        (() => {
          const fieldset = document.querySelector('[data-testid="variant-picker"]');
          const sizes = [...fieldset.querySelectorAll('label > span')].map(span => {
            const rect = span.getBoundingClientRect();
            return { right: rect.right, top: rect.top };
          });
          return {
            innerWidth: window.innerWidth,
            scrollWidth: document.documentElement.scrollWidth,
            fieldsetRight: fieldset.getBoundingClientRect().right,
            sizes: sizes
          };
        })()
      JS

      assert_equal width, layout["innerWidth"]
      assert_operator layout["scrollWidth"], :<=, layout["innerWidth"]
      layout["sizes"].each do |size|
        assert_operator size["right"], :<=, layout["fieldsetRight"], "#{width}px에서 사이즈가 영역을 벗어남"
      end
      assert_equal layout["sizes"][0]["top"], layout["sizes"][1]["top"], "#{width}px에서 사이즈가 세로로 쌓임"
    end
  ensure
    browser.execute_cdp("Emulation.clearDeviceMetricsOverride") if browser
  end

  # 시나리오 8: 상품 카드 클릭
  test "상품 카드 클릭 시 상세 페이지로 이동하는가" do
    visit root_path

    # 첫 번째 상품 카드 클릭
    first("#ranking h3 a").click

    # 상세 페이지로 이동했는가
    assert_current_path %r{/products/\d+}
  end
end
