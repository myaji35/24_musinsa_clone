# gem에서 제공하는 로컬 JS와 Stimulus 컨트롤러를 등록

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# html5-qrcode 2.3.8 (Apache-2.0) — 자립형 단일 ESM 번들(vendor 로컬).
pin "html5-qrcode", to: "html5-qrcode.js"
