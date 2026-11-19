import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const active = this.element.querySelector('[aria-current="page"]')
    if (!active) return

    const containerRect = this.element.getBoundingClientRect()
    const activeRect = active.getBoundingClientRect()
    if (activeRect.left < containerRect.left || activeRect.right > containerRect.right) {
      this.element.scrollLeft += activeRect.left - containerRect.left + (activeRect.width - containerRect.width) / 2
    }
  }
}
