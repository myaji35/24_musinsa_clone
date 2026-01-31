import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nested-form"
export default class extends Controller {
  static targets = ["container", "template", "item"]

  add(event) {
    event.preventDefault()

    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()

    const item = event.target.closest('[data-nested-form-target="item"]')

    // 이미 저장된 레코드는 _destroy 플래그 설정
    const destroyInput = item.querySelector('input[name*="_destroy"]')
    if (destroyInput) {
      destroyInput.value = "1"
      item.style.display = "none"
    } else {
      // 새로 추가된 레코드는 DOM에서 제거
      item.remove()
    }
  }
}
