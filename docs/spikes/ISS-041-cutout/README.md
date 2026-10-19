# ISS-041 누끼 품질 스파이크 — 자체 호스팅 rembg 모델 비교

- 실측일: 2026-10-18 (대표님 맥, Apple Silicon CPU, GPU 없음)
- 결정 배경: 대표님이 유료 Photoroom·fal 대신 **무료 자체 호스팅(rembg + BiRefNet, MIT 라이선스)** 추천안을 승인했다. 그래서 비교 대상을 유료 공급사 2곳에서 rembg 무료 모델 3종으로 바꿨다.
- 이미지: 실제 사입 사진이 아직 없다(ISS-068 대기). 그래서 저장소에 있는 상품·모델 이미지 10장으로 대신했다. 긴 변은 1024px로 줄였다. 실사입 사진이 들어오면 같은 스크립트로 다시 확인한다.

## 실측표 (장당 처리 시간, 모델 로딩 제외)

| 모델 | 평균(초) | 최대(초) | 장당 비용 | 라이선스 |
|---|---|---|---|---|
| **birefnet-general** (채택) | **4.62** | 4.73 | **$0** | MIT |
| isnet-general-use | 1.16 | 1.83 | $0 | Apache-2.0 |
| u2net | 0.39 | 1.00 | $0 | Apache-2.0 |

- 모델을 처음 쓸 때는 내려받기와 로딩에 시간이 걸린다(birefnet 약 90초, 약 1GB). 그 뒤로는 서버 프로세스 안에 캐시된다.
- 원본 숫자는 `timings.json`에 있다.

## 품질

`comparison.jpg`의 위에서부터 birefnet, isnet, u2net 순서다. 체크무늬 배경 위에 결과를 놓았다.

- 세 모델 모두 인물과 의류 외곽선을 무난하게 분리했다.
- birefnet은 퍼 후드 털 끝, 머리카락, 가방 끈처럼 가는 경계가 가장 깔끔하다.
- 행거에 걸린 상품컷(`product_coat`)은 세 모델 모두 행거 일부가 남는다. 상품 단독 촬영 가이드에 "행거 없이 촬영"을 넣어야 한다.

## 결론

- 1차 공급사는 **자체 호스팅 rembg `birefnet-general`**로 정한다(ISS-043 어댑터 `Cutouts::RembgAdapter`).
- 장당 약 5초라서 백그라운드 job(Solid Queue)으로 처리한다.
- 대량 일괄 처리처럼 속도가 우선이면 `u2net`으로 바꿀 수 있다(어댑터의 `MODEL` 상수).
- 결과 PNG 10장: `birefnet-general/`

## 재실행

```bash
python3.12 -m venv venv && venv/bin/pip install "rembg[cpu,cli]"
venv/bin/rembg s --host 127.0.0.1 --port 7000 --no-ui   # 앱은 REMBG_URL(기본 http://127.0.0.1:7000)로 호출
```
