"""공급사 엑셀과 행에 고정된 그림 세 장을 생성한다."""
from pathlib import Path
from openpyxl import Workbook
from openpyxl.drawing.image import Image
from PIL import Image as PILImage
from io import BytesIO

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "test/fixtures/files/supplier_sample.xlsx"
workbook = Workbook()
sheet = workbook.active
sheet.append(["상품명", "상품코드", "공급가", "판매가", "카테고리", "브랜드", "색상", "사이즈", "소재", "재고"])
sheet.append(["셔츠", "SUP-001", 12000, 29000, "상의", "", "검정, 흰색", "S/M", "면", 15])
sheet.append(["재킷", "SUP-002", 22000, 49000, "아우터", "브랜드B", "남색", "FREE", "울", 8])
sheet.append(["스커트", "SUP-003", 10000, 25000, "하의", "브랜드C", "베이지", "S,L", "린넨", 5])
sheet.append(["가격 없는 상품", "SUP-004", 10000, None, "상의", "브랜드D", "검정", "M", "면", 3])
for row, name in zip((2, 3, 4), ("yuna-frame-1.jpg", "yuna-frame-5.jpg", "yuna-frame-8.jpg")):
    source = ROOT / "public/intro" / name
    with PILImage.open(source) as original:
        resized = original.copy()
        resized.thumbnail((240, 2400))
        buffer = BytesIO()
        resized.convert("RGB").save(buffer, "JPEG", quality=75)
        buffer.seek(0)
    picture = Image(buffer)
    sheet.add_image(picture, f"C{row}")
workbook.save(OUTPUT)
