import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "status"]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.textContent)
      this.statusTarget.textContent = "복사했습니다."
    } catch {
      this.statusTarget.textContent = "복사하지 못했습니다. 본문을 선택해 복사해 주세요."
    }
  }
}
