import { Controller } from "@hotwired/stimulus"

// 처리 중 상태가 보이는 동안 감싼 Turbo Frame 을 주기적으로 다시 불러온다.
// 프레임 내용이 바뀌면 이 요소도 새로 연결되므로 한 번씩만 예약한다.
export default class extends Controller {
  static values = { url: String, interval: { type: Number, default: 2000 } }

  connect() {
    this.timer = setTimeout(() => {
      const frame = this.element.closest("turbo-frame")
      if (!frame) return
      const separator = this.urlValue.includes("?") ? "&" : "?"
      frame.src = `${this.urlValue}${separator}t=${Date.now()}`
    }, this.intervalValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
