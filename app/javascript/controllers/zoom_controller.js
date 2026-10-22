import { Controller } from "@hotwired/stimulus"

// 상품 상세 사진 돋보기: 마우스가 있는 기기에서 사진 위를 움직이면 커서 지점을 확대한다.
// 큰 화면용 1440px 사진(srcset)이 로드되므로 확대해도 선명하다. 터치 기기에서는 아무것도 하지 않는다.
const SCALE = 2.4

export default class extends Controller {
  static targets = ["image"]

  connect() {
    this.enabled = window.matchMedia("(hover: hover) and (pointer: fine)").matches
  }

  enter(event) {
    if (!this.enabled) return
    // 확대할 때는 1440px 원본을 쓴다(일반 화면에서는 720px 사진이 로드돼 있으므로)
    const large = this.imageTarget.dataset.zoomSrc
    if (large && !this.swapped) {
      this.imageTarget.srcset = `${large} 1440w`
      this.swapped = true
    }
    this.imageTarget.style.transition = "transform .15s ease-out"
    this.imageTarget.style.transform = `scale(${SCALE})`
    this.move(event)
  }

  move(event) {
    if (!this.enabled) return
    const rect = this.element.getBoundingClientRect()
    const x = ((event.clientX - rect.left) / rect.width) * 100
    const y = ((event.clientY - rect.top) / rect.height) * 100
    this.imageTarget.style.transformOrigin = `${x}% ${y}%`
  }

  leave() {
    if (!this.enabled) return
    this.imageTarget.style.transform = ""
    this.imageTarget.style.transformOrigin = ""
  }
}
