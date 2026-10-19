import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["video"]

  connect() {
    this.observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) entry.target.pause()
      })
    })
    this.videoTargets.forEach(video => this.observer.observe(video))
  }

  disconnect() {
    this.observer?.disconnect()
    this.videoTargets.forEach(video => video.pause())
  }

  async toggle(event) {
    const video = event.currentTarget.closest("article").querySelector("video")
    if (!video.paused) {
      video.pause()
      return
    }

    this.videoTargets.forEach(other => {
      if (other !== video) other.pause()
    })
    if (!video.hasAttribute("src")) video.src = video.dataset.src
    try {
      await video.play()
    } catch {
      this.updateButton(video)
    }
  }

  sync(event) {
    const video = event.currentTarget
    if (!video.paused) {
      this.videoTargets.forEach(other => {
        if (other !== video) other.pause()
      })
    }
    this.updateButton(video)
  }

  updateButton(video) {
    const button = video.closest("article").querySelector("button")
    const action = video.paused ? "재생" : "정지"
    button.setAttribute("aria-pressed", String(!video.paused))
    button.setAttribute("aria-label", `${button.dataset.name} 런웨이 영상 ${action}`)
    button.textContent = action
  }
}
