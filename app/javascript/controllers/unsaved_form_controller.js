import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status"]

  connect() {
    this.initialValues = new Map(this.fields.map((field) => [field, this.valueOf(field)]))
    this.dirtyCount = 0
    this.isSaving = false
    this.beforeUnload = this.beforeUnload.bind(this)
    this.beforeVisit = this.beforeVisit.bind(this)
    window.addEventListener("beforeunload", this.beforeUnload)
    document.addEventListener("turbo:before-visit", this.beforeVisit)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.beforeUnload)
    document.removeEventListener("turbo:before-visit", this.beforeVisit)
  }

  get fields() {
    return Array.from(this.element.querySelectorAll("input, textarea, select"))
  }

  valueOf(field) {
    if (field.type === "checkbox" || field.type === "radio") return field.checked
    if (field.multiple) return JSON.stringify(Array.from(field.selectedOptions, (option) => option.value))
    return field.value
  }

  track() {
    this.dirtyCount = 0
    for (const field of this.fields) {
      const dirty = this.initialValues.has(field) && this.valueOf(field) !== this.initialValues.get(field)
      field.toggleAttribute("data-dirty", dirty)
      if (dirty) this.dirtyCount++
    }
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = this.dirtyCount ? `저장 안 된 변경 ${this.dirtyCount}칸` : "변경 없음"
      this.statusTarget.classList.toggle("text-red-600", this.dirtyCount > 0)
      this.statusTarget.classList.toggle("font-bold", this.dirtyCount > 0)
    }
  }

  saving() {
    this.isSaving = true
  }

  beforeUnload(event) {
    if (!this.dirtyCount || this.isSaving) return
    event.preventDefault()
    event.returnValue = ""
  }

  beforeVisit(event) {
    if (this.dirtyCount && !this.isSaving && !window.confirm("저장하지 않은 변경이 있습니다. 이 화면을 떠날까요?")) {
      event.preventDefault()
    }
  }
}
