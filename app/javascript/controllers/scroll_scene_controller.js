import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section"]

  connect() {
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.onMotionChange = this.onMotionChange.bind(this)
    this.onScroll = this.onScroll.bind(this)
    this.frame = null

    this.reducedMotion.addEventListener("change", this.onMotionChange)
    this.onMotionChange()
  }

  disconnect() {
    this.reducedMotion.removeEventListener("change", this.onMotionChange)
    this.removeScrollListeners()
    if (this.frame !== null) cancelAnimationFrame(this.frame)
    this.frame = null
  }

  onMotionChange() {
    this.removeScrollListeners()
    if (this.frame !== null) cancelAnimationFrame(this.frame)
    this.frame = null

    if (this.reducedMotion.matches) {
      this.sectionTargets.forEach((section) => section.style.setProperty("--p", "1"))
      return
    }

    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onScroll, { passive: true })
    this.onScroll()
  }

  removeScrollListeners() {
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onScroll)
  }

  onScroll() {
    if (this.frame !== null) return
    this.frame = requestAnimationFrame(() => {
      this.frame = null
      this.sectionTargets.forEach((section) => {
        const rect = section.getBoundingClientRect()
        const distance = rect.height - window.innerHeight
        const progress = distance > 0 ? Math.min(1, Math.max(0, -rect.top / distance)) : 1
        section.style.setProperty("--p", String(progress))
      })
    })
  }
}
