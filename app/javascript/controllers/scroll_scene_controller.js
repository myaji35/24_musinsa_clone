import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section", "hero"]

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

    this.syncHeroVideo()

    if (this.reducedMotion.matches) {
      this.sectionTargets.forEach((section) => this.updateSection(section, 1))
      return
    }

    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onScroll, { passive: true })
    this.onScroll()
  }

  // 움직임 줄이기 설정이면 자동재생을 멈추고 포스터 + 재생 컨트롤만 보여준다(WCAG 2.2.2).
  syncHeroVideo() {
    this.heroTargets.forEach((video) => {
      if (this.reducedMotion.matches) {
        video.pause()
        video.controls = true
      } else {
        video.controls = false
        video.play().catch(() => {})
      }
    })
  }

  updateSection(section, progress) {
    section.style.setProperty("--p", String(progress))
    section.querySelectorAll(".intro-cta").forEach((cta) => {
      const ready = this.reducedMotion.matches || progress >= 0.75
      cta.classList.toggle("is-ready", ready)
      cta.inert = !ready
    })
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
        this.updateSection(section, progress)
      })
    })
  }
}
