import { Application } from "@hotwired/stimulus"

// Stimulus를 시작하고 브라우저에서 접근할 수 있도록 노출
const application = Application.start()
application.debug = false
window.Stimulus = application

export { application }
