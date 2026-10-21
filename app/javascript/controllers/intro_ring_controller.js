import { Controller } from "@hotwired/stimulus"

// 캐릭터 링: 스크롤과 분리해 천천히 자동 회전. 끌어서 돌리거나 버튼으로 한 칸씩 넘긴다.
// 마우스를 올리거나 포커스가 있으면 멈추고, 화면 밖이거나 움직임 줄이기 설정이면 돌지 않는다.
const STEP = 18 // 카드 20장 = 360도
const SPEED = 6 // 초당 회전 각도

export default class extends Controller {
  static targets = ["ring", "viewport"]

  connect() {
    this.angle = 0
    this.target = null
    this.paused = false
    this.visible = false
    this.dragX = null
    this.last = null
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.tick = this.tick.bind(this)

    this.observer = new IntersectionObserver(([entry]) => {
      this.visible = entry.isIntersecting
      this.schedule()
    })
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer.disconnect()
    if (this.frame) cancelAnimationFrame(this.frame)
    this.frame = null
  }

  pause() { this.paused = true }

  resume() {
    if (this.dragX !== null || this.element.contains(document.activeElement)) return
    this.paused = false
    this.schedule()
  }

  previous() { this.stepBy(1) }

  next() { this.stepBy(-1) }

  stepBy(direction) {
    this.paused = true
    this.target = Math.round((this.target ?? this.angle) / STEP) * STEP + direction * STEP
    this.schedule()
  }

  grab(event) {
    if (event.pointerType === "mouse" && event.button !== 0) return
    this.dragX = event.clientX
    this.paused = true
    this.target = null
    this.viewportTarget.classList.add("is-dragging")
  }

  drag(event) {
    if (this.dragX === null) return
    this.angle += (event.clientX - this.dragX) * 0.3
    this.dragX = event.clientX
    this.render()
  }

  release(event) {
    if (this.dragX === null) return
    this.dragX = null
    this.viewportTarget.classList.remove("is-dragging")
    if (event.pointerType !== "mouse") this.resume()
  }

  schedule() {
    if (this.frame || !this.visible || this.reducedMotion.matches) return
    this.last = null
    this.frame = requestAnimationFrame(this.tick)
  }

  tick(now) {
    this.frame = null
    const dt = this.last === null ? 0 : Math.min(0.1, (now - this.last) / 1000)
    this.last = now

    if (this.target !== null) {
      const diff = this.target - this.angle
      this.angle += diff * Math.min(1, dt * 8)
      if (Math.abs(diff) < 0.05) { this.angle = this.target; this.target = null }
    } else if (!this.paused && this.dragX === null) {
      this.angle -= SPEED * dt
    }
    this.render()

    const moving = this.target !== null || (!this.paused && this.dragX === null)
    if (moving && this.visible) this.frame = requestAnimationFrame(this.tick)
  }

  render() {
    this.ringTarget.style.setProperty("--intro-ring-angle", `${this.angle}deg`)
  }
}
