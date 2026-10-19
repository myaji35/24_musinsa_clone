# 홈 런웨이 클립 (ISS-118)

글자(이름·브랜드·AI 배지)가 구워지지 않은 원본에서 앞 10초만 잘라 웹용으로 재인코딩했다.
이름·'AI 가상인물' 표시는 HTML 오버레이로만 붙인다.

- 원본(clips_v2 재생성본): persona/runway-04/clips_v2/{KangUNA,YunCHAEI,MoreauLEA,OhDAEUN}.mp4
- 원본(clips): persona/runway-04/clips/{SeoHARIN,TanakaMIO,ParkJADE,HanSOYUL,ChenMAYA,SoERIN}.mp4
- 영상: `ffmpeg -t 10 -an -vf scale=720:1280 -c:v libx264 -preset slow -b:v 900k -maxrate 1000k -bufsize 2000k -movflags +faststart`
- 포스터: 7초 프레임, 720×1280 JPEG ≤ 50KB
- 라이선스: 자체 생성 AI 가상인물 영상(실존 인물 아님)
