import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["summary"]

  connect() {
    this.calculate()
  }

  calculate() {
    let count = 0
    let total = 0

    this.element.querySelectorAll(".purchase-order-item").forEach((item) => {
      if (item.querySelector('[name$="[_destroy]"]')?.value === "1" || getComputedStyle(item).display === "none") return

      const quantity = Number(item.querySelector('[name$="[quantity]"]')?.value) || 0
      const unitPrice = Number(item.querySelector('[name$="[unit_price]"]')?.value) || 0
      const subtotal = quantity * unitPrice
      count += 1
      total += subtotal
      item.querySelector("[data-po-total-subtotal]").textContent = `소계 ₩${this.format(subtotal)}`
    })

    this.summaryTarget.textContent = `품목 ${count}개 · 합계 ₩${this.format(total)}`
  }

  format(amount) {
    return Math.round(amount).toLocaleString("ko-KR")
  }
}
