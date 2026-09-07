import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

// importmap에 등록된 Stimulus 컨트롤러 자동 로드
eagerLoadControllersFrom("controllers", application)
