import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "toggle", "form", "pageUrl", "message", "submit"]

  toggle() {
    if (!this.panelTarget.hidden) return this.close()
    this.panelTarget.hidden = false
    this.toggleTarget.setAttribute("aria-expanded", "true")
    this.formTarget.querySelector("select").focus()
  }

  close() {
    this.panelTarget.hidden = true
    this.toggleTarget.setAttribute("aria-expanded", "false")
    this.toggleTarget.focus()
  }

  async submit(event) {
    event.preventDefault()
    event.stopImmediatePropagation()
    if (this.submitTarget.disabled) return
    this.pageUrlTarget.value = window.location.href
    this.submitTarget.disabled = true
    this.messageTarget.textContent = "보내는 중…"
    try {
      const response = await fetch(this.formTarget.action, {
        method: "POST",
        headers: { "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
        body: new FormData(this.formTarget)
      })
      if (![201, 422].includes(response.status) || !response.headers.get("content-type")?.includes("application/json")) {
        throw new Error("request failed")
      }
      const result = await response.json()
      this.messageTarget.textContent = result.message
      if (response.ok) this.formTarget.reset()
    } catch {
      this.messageTarget.textContent = "전송하지 못했어요. 로그인 상태를 확인하고 다시 보내 주세요."
    } finally {
      this.submitTarget.disabled = false
    }
  }
}
