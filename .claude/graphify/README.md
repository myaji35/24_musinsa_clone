# graphify (자동 운영)

이 프로젝트는 graphify 그래프를 **코드 변경 시 자동 증분 갱신**한다.

- **초기 빌드**: 세션 시작 시 graph.json이 없으면 session-resume이 빌드 신호를 띄움
  → Claude가 `/graphify . --update --no-viz` 실행 → `graphify-out/graph.json` 생성
- **증분 갱신**: 코드/문서 편집(Write/Edit) 시 post-code-change → graphify-autobuild가
  `.rebuild-needed` 신호를 남김(디바운스 90초) → 다음 세션 시작 시 증분 반영
- **활용**: agent-harness가 GENERATE_CODE/REFACTOR/FIX_BUG claim 직후 graph를 조회해
  의존성 맹점 제거 + 토큰 절감 (graphify-integration 스킬)

## 시맨틱 검색 (semantic/, 로컬 Ollama 임베딩)
`semantic/`는 harness-core symlink — 의미 기반 검색 모듈. Ollama 미설치 시 자동 skip($0).
- 사전조건: `ollama pull nomic-embed-text`
- 임베딩 빌드: `python3 .claude/graphify/semantic/vector_cache.py graphify-out/graph.json graphify-out/.vector_cache.json`
- 시맨틱 질의: `python3 .claude/graphify/semantic/semantic_query.py graphify-out/.vector_cache.json "<질문>" --top-k 5`
- BFS query로 도달 못 하는 의미상 유사 노드를 코사인 유사도로 발견. autobuild가 graph 갱신 시 증분 임베딩.

수동 전체 재빌드: `/graphify . --wiki`
