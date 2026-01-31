import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="variant-selector"
export default class extends Controller {
  static targets = ["quantity", "stock", "totalPrice", "colorButton", "sizeButton", "selectedVariant"]
  static values = {
    variants: Array,
    basePrice: Number
  }

  connect() {
    console.log("Variant selector controller connected")
    this.selectedColor = null
    this.selectedSize = null
    this.currentQuantity = 1

    // 초기화: 첫 번째 variant 선택
    if (this.hasColorButtonTarget) {
      const firstColorButton = this.colorButtonTargets[0]
      if (firstColorButton) {
        this.selectedColor = firstColorButton.dataset.color
      }
    }

    if (this.hasSizeButtonTarget) {
      const firstSizeButton = this.sizeButtonTargets[0]
      if (firstSizeButton) {
        this.selectedSize = firstSizeButton.dataset.size
      }
    }

    this.updateVariant()
  }

  // 색상 선택
  selectColor(event) {
    event.preventDefault()
    const button = event.currentTarget
    this.selectedColor = button.dataset.color

    // 모든 색상 버튼 비활성화 스타일
    this.colorButtonTargets.forEach(btn => {
      btn.classList.remove("bg-black", "text-white", "border-black")
      btn.classList.add("bg-white", "text-gray-700", "border-gray-300")
    })

    // 선택된 버튼 활성화 스타일
    button.classList.remove("bg-white", "text-gray-700", "border-gray-300")
    button.classList.add("bg-black", "text-white", "border-black")

    this.updateVariant()
  }

  // 사이즈 선택
  selectSize(event) {
    event.preventDefault()
    const button = event.currentTarget
    this.selectedSize = button.dataset.size

    // 모든 사이즈 버튼 비활성화 스타일
    this.sizeButtonTargets.forEach(btn => {
      btn.classList.remove("bg-black", "text-white", "border-black")
      btn.classList.add("bg-white", "text-gray-700", "border-gray-300")
    })

    // 선택된 버튼 활성화 스타일
    button.classList.remove("bg-white", "text-gray-700", "border-gray-300")
    button.classList.add("bg-black", "text-white", "border-black")

    this.updateVariant()
  }

  // Variant 업데이트
  updateVariant() {
    if (!this.selectedColor || !this.selectedSize) {
      return
    }

    // variants 데이터에서 매칭되는 variant 찾기
    const variant = this.findVariant(this.selectedColor, this.selectedSize)

    if (variant) {
      // 재고 업데이트
      if (this.hasStockTarget) {
        this.stockTarget.textContent = variant.stock || 0

        // 재고 부족 경고
        if (variant.stock <= 0) {
          this.stockTarget.classList.add("text-red-600")
          this.stockTarget.textContent = "품절"
        } else if (variant.stock <= (variant.min_stock || 5)) {
          this.stockTarget.classList.add("text-orange-600")
        } else {
          this.stockTarget.classList.remove("text-red-600", "text-orange-600")
        }
      }

      // 수량 제한 (재고 초과 방지)
      if (this.currentQuantity > variant.stock) {
        this.currentQuantity = Math.max(1, variant.stock)
        if (this.hasQuantityTarget) {
          this.quantityTarget.value = this.currentQuantity
        }
      }

      // hidden input에 선택된 variant_id 저장 (폼 제출용)
      if (this.hasSelectedVariantTarget) {
        this.selectedVariantTarget.value = variant.id
      }

      this.updateTotalPrice()
    }
  }

  // Variant 찾기
  findVariant(color, size) {
    if (!this.hasVariantsValue) {
      return null
    }

    return this.variantsValue.find(v =>
      v.color.toLowerCase() === color.toLowerCase() &&
      v.size.toUpperCase() === size.toUpperCase()
    )
  }

  // 수량 증가
  increaseQuantity(event) {
    event.preventDefault()

    const variant = this.findVariant(this.selectedColor, this.selectedSize)
    const maxStock = variant ? variant.stock : 999

    if (this.currentQuantity < maxStock) {
      this.currentQuantity++
      if (this.hasQuantityTarget) {
        this.quantityTarget.value = this.currentQuantity
      }
      this.updateTotalPrice()
    } else {
      this.showStockWarning()
    }
  }

  // 수량 감소
  decreaseQuantity(event) {
    event.preventDefault()

    if (this.currentQuantity > 1) {
      this.currentQuantity--
      if (this.hasQuantityTarget) {
        this.quantityTarget.value = this.currentQuantity
      }
      this.updateTotalPrice()
    }
  }

  // 총 가격 업데이트
  updateTotalPrice() {
    if (!this.hasTotalPriceTarget || !this.hasBasePriceValue) {
      return
    }

    const total = this.basePriceValue * this.currentQuantity
    this.totalPriceTarget.textContent = this.formatPrice(total)
  }

  // 가격 포맷팅
  formatPrice(price) {
    return new Intl.NumberFormat('ko-KR').format(price)
  }

  // 재고 부족 경고
  showStockWarning() {
    alert("선택하신 수량이 재고를 초과했습니다.")
  }

  // 장바구니 추가
  addToCart(event) {
    event.preventDefault()

    const variant = this.findVariant(this.selectedColor, this.selectedSize)

    if (!variant) {
      alert("옵션을 선택해주세요.")
      return
    }

    if (variant.stock <= 0) {
      alert("품절된 상품입니다.")
      return
    }

    // TODO: 장바구니 추가 로직 (Story 4 에서 구현)
    console.log("장바구니 추가:", {
      variant_id: variant.id,
      quantity: this.currentQuantity,
      color: this.selectedColor,
      size: this.selectedSize
    })

    alert(`장바구니에 추가되었습니다.\n색상: ${this.selectedColor}\n사이즈: ${this.selectedSize}\n수량: ${this.currentQuantity}`)
  }

  // 바로구매
  buyNow(event) {
    event.preventDefault()

    const variant = this.findVariant(this.selectedColor, this.selectedSize)

    if (!variant) {
      alert("옵션을 선택해주세요.")
      return
    }

    if (variant.stock <= 0) {
      alert("품절된 상품입니다.")
      return
    }

    // TODO: 바로구매 로직 (Story 4 에서 구현)
    console.log("바로구매:", {
      variant_id: variant.id,
      quantity: this.currentQuantity,
      color: this.selectedColor,
      size: this.selectedSize
    })

    alert(`바로구매를 진행합니다.\n색상: ${this.selectedColor}\n사이즈: ${this.selectedSize}\n수량: ${this.currentQuantity}`)
  }
}
