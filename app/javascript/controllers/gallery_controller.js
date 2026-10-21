import { Controller } from "@hotwired/stimulus"

// 상품 상세 갤러리: 썸네일을 누르면 메인 이미지를 바꾸고, 실물 사진이면 '가상 인물' 배지를 숨긴다.
export default class extends Controller {
  static targets = ["main", "thumb", "badge"]

  show(event) {
    const thumb = event.currentTarget
    this.mainTarget.src = thumb.dataset.src
    this.mainTarget.alt = thumb.dataset.alt
    this.thumbTargets.forEach((el) => {
      const active = el === thumb
      el.classList.toggle("border-black", active)
      el.classList.toggle("border-transparent", !active)
      el.setAttribute("aria-pressed", active)
    })
    if (this.hasBadgeTarget) this.badgeTarget.hidden = thumb.dataset.real === "true"
  }
}
