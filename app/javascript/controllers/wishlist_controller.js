import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="wishlist"
export default class extends Controller {
  static targets = ["icon", "button"]
  static values = {
    productId: Number,
    active: { type: Boolean, default: false }
  }

  connect() {
    // LocalStorage에서 찜 상태 로드
    this.loadWishlistState()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    this.activeValue = !this.activeValue
    this.saveWishlistState()
    this.updateUI()
  }

  loadWishlistState() {
    const wishlist = this.getWishlist()
    this.activeValue = wishlist.includes(this.productIdValue)
    this.updateUI()
  }

  saveWishlistState() {
    let wishlist = this.getWishlist()

    if (this.activeValue) {
      // 찜 추가
      if (!wishlist.includes(this.productIdValue)) {
        wishlist.push(this.productIdValue)
      }
    } else {
      // 찜 제거
      wishlist = wishlist.filter(id => id !== this.productIdValue)
    }

    localStorage.setItem('wishlist', JSON.stringify(wishlist))
  }

  getWishlist() {
    const stored = localStorage.getItem('wishlist')
    return stored ? JSON.parse(stored) : []
  }

  updateUI() {
    if (this.hasButtonTarget) {
      if (this.activeValue) {
        this.buttonTarget.classList.add('text-red-500')
        this.buttonTarget.classList.remove('text-gray-400')
      } else {
        this.buttonTarget.classList.add('text-gray-400')
        this.buttonTarget.classList.remove('text-red-500')
      }
    }

    // SVG 아이콘 fill 처리
    if (this.hasIconTarget) {
      if (this.activeValue) {
        this.iconTarget.setAttribute('fill', 'currentColor')
      } else {
        this.iconTarget.setAttribute('fill', 'none')
      }
    }
  }
}
