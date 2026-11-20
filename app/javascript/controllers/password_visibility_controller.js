import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "toggle" ]

  connect() {
    this.toggleTarget.hidden = false
  }

  toggle() {
    const visible = this.inputTarget.type === "password"
    this.inputTarget.type = visible ? "text" : "password"
    this.toggleTarget.textContent = visible ? "숨기기" : "보기"
    this.toggleTarget.setAttribute("aria-pressed", String(visible))
    this.toggleTarget.setAttribute("aria-label", visible ? "비밀번호 숨기기" : "비밀번호 보기")
  }
}
