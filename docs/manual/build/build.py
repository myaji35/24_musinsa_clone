#!/usr/bin/env python3
"""Render the unchanged manuscript twice; no Markdown package required."""
import base64
import html
import json
import math
import re
import shutil
import subprocess
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
MANUAL = HERE.parent
OUT = MANUAL / 'out'
WORK = HERE / 'out' / 'pdf'
SHOTS = HERE / 'out' / 'shots'
ANNOTATED = HERE / 'out' / 'annotated'
VERSION = '1.2'
NAME = f'JIEUM_운영자매뉴얼_v{VERSION}'
FONT = Path('/Volumes/E_SSD/02_GitHub.nosync/0058_insuPro/videos/shorts/engine/fonts')
CIRCLES = '①②③④⑤⑥⑦⑧⑨⑩'


def esc(value):
    return html.escape(str(value), quote=True)


def inline(text):
    # Only manuscript's inline syntax; raw HTML is always escaped.
    parts = re.split(r'(`[^`]+`|\*\*.+?\*\*)', text)
    return ''.join('<code>' + esc(p[1:-1]) + '</code>' if p.startswith('`') else
                   '<strong>' + esc(p[2:-2]) + '</strong>' if p.startswith('**') else esc(p)
                   for p in parts)


def blocks(lines):
    result = []
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            i += 1
            continue
        if line.startswith('|'):
            rows = []
            while i < len(lines) and lines[i].strip().startswith('|'):
                cells = [c.strip() for c in lines[i].strip().strip('|').split('|')]
                if not all(re.fullmatch(r':?-+:?', c) for c in cells):
                    rows.append(cells)
                i += 1
            result.append('<table><thead><tr>' + ''.join('<th>' + inline(c) + '</th>' for c in rows[0]) +
                          '</tr></thead><tbody>' + ''.join('<tr>' + ''.join('<td>' + inline(c) + '</td>' for c in r) + '</tr>' for r in rows[1:]) + '</tbody></table>')
            continue
        if re.match(r'^\d+\. ', line):
            result.append('<ol class="steps">')
            while i < len(lines) and re.match(r'^\d+\. ', lines[i].strip()):
                match = re.match(r'^(\d+)\. (.*)', lines[i].strip())
                n = int(match[1])
                number = CIRCLES[n - 1] if n <= len(CIRCLES) else str(n)
                result.append(f'<li><b class="step">{number}</b><div>{inline(match[2])}</div></li>')
                i += 1
            result.append('</ol>')
            continue
        if line.startswith('- '):
            result.append('<p class="bullet">• ' + inline(line[2:]) + '</p>')
        elif line.startswith('확인할 것:'):
            result.append('<aside class="caution"><b>주의</b><p>' + inline(line) + '</p></aside>')
        elif line == '따라 하기':
            result.append('<h2>' + inline(line) + '</h2>')
        else:
            result.append('<p>' + inline(line) + '</p>')
        i += 1
    return ''.join(result)


def parse():
    text = (MANUAL / 'operator-manual.md').read_text(encoding='utf-8')
    pieces = re.split(r'^## (\d+)\. (.+)\n', text, flags=re.M)
    chapters = []
    for i in range(1, len(pieces), 3):
        chapters.append({'n': int(pieces[i]), 'title': pieces[i + 1], 'lines': pieces[i + 2].splitlines()})
    if [c['n'] for c in chapters] != list(range(12)):
        raise RuntimeError('원고에는 0~11장이 순서대로 있어야 합니다')
    return pieces[0], chapters


def figures(chapter, points, screens):
    result = []
    counter = 0
    described = set()
    for screen in screens:
        if screen['chapter'] != chapter:
            continue
        meta_path = SHOTS / (screen['id'] + '.json')
        image_path = SHOTS / (screen['id'] + '.png')
        if not meta_path.is_file() or not image_path.is_file():
            raise RuntimeError(f'캡처가 없습니다: {screen["id"]}. capture.mjs를 먼저 실행하세요')
        meta = json.loads(meta_path.read_text(encoding='utf-8'))
        configured = {p['n']: p['label'] for p in screen['callouts']}
        # Ignore stale callouts belonging to another figure in this chapter.
        callouts = [p for p in meta['callouts'] if p['n'] in configured]
        width, height = meta['width'], meta['height']
        source = Image.open(image_path).convert('RGB')
        scale = meta['deviceScaleFactor']
        if any(abs(actual - round(expected * scale)) > 2
               for actual, expected in zip(source.size, (width, height))):
            raise RuntimeError(f'{screen["id"]}: PNG와 캡처 메타데이터 크기가 다릅니다')
        scale_x, scale_y = source.width / width, source.height / height
        # Tall pages are cut into readable panels rather than shrunk to illegibility.
        panels = 1 if screen['chapter'] == 6 else max(1, math.ceil(height / 880))
        panel_height = height / panels
        for panel in range(panels):
            counter += 1
            top = panel * panel_height
            annotations = []
            placed, bounds = [], []
            descriptions = []
            for point in callouts:
                box = point['box']
                if not (top <= box['y'] < top + panel_height):
                    continue
                x, y = box['x'], box['y'] - top
                h = min(box['height'], panel_height - y)
                # At the 174 mm print width, badge diameter is 28 CSS px.
                radius = width * (7 / 174) / 2
                gap = 6
                if screen.get('calloutPlacement') == 'top':
                    cx, cy = x + box['width'] / 2, y - radius - gap
                    if point['n'] == 1:
                        cx = radius + gap
                elif x >= 2 * radius + gap:
                    cx, cy = x - radius - gap, y + h / 2
                elif y >= 2 * radius + gap:
                    cx, cy = x + box['width'] / 2, y - radius - gap
                else:
                    cx, cy = x + box['width'] + radius + gap, y + h / 2
                original = (cx, cy)
                # Keep badges clear of one another and of every highlighted target.
                while True:
                    collisions = [(px, py) for px, py in placed if math.hypot(cx - px, cy - py) < 2 * radius + gap]
                    if not collisions:
                        break
                    cy = max(py + 2 * radius + gap for _, py in collisions)
                targets = [p['box'] for p in callouts if top <= p['box']['y'] < top + panel_height]
                if any(cx + radius > b['x'] and cx - radius < b['x'] + b['width'] and
                       cy + radius > b['y'] - top and cy - radius < b['y'] - top + b['height'] for b in targets):
                    cx = -radius - gap
                    while any(math.hypot(cx - px, cy - py) < 2 * radius + gap for px, py in placed):
                        cy += 2 * radius + gap
                placed.append((cx, cy))
                bounds.append((cx - radius - 2, cy - radius - 2, cx + radius + 2, cy + radius + 2))
                annotations.append((x, y, box['width'], h, cx, cy, radius, point['n']))
                descriptions.append(point['n'])
                described.add(point['n'])
            left = min([-18] + [b[0] for b in bounds])
            upper = min([0] + [b[1] for b in bounds])
            right = max([width + 18] + [b[2] for b in bounds])
            bottom = max([panel_height] + [b[3] for b in bounds])
            # Include outside badges in the bitmap, so the image and annotations
            # always share the same print scaling and layout bounds.
            canvas = Image.new('RGB', (math.ceil((right - left) * scale_x),
                                      math.ceil((bottom - upper) * scale_y)), 'white')
            canvas.paste(source.crop((0, round(top * scale_y), source.width,
                                      round((top + panel_height) * scale_y))),
                         (round(-left * scale_x), round(-upper * scale_y)))
            draw = ImageDraw.Draw(canvas)
            def xy(x, y):
                return ((x - left) * scale_x, (y - upper) * scale_y)
            color = '#C8102E'
            stroke = max(2, round(scale))
            for x, y, w, h, cx, cy, radius, number in annotations:
                draw.rectangle([xy(x, y), xy(x + w, y + h)], outline=color, width=stroke)
                tx, ty = min(max(cx, x), x + w), min(max(cy, y), y + h)
                draw.line([xy(cx, cy), xy(tx, ty)], fill=color, width=stroke)
            for x, y, w, h, cx, cy, radius, number in annotations:
                draw.ellipse([xy(cx - radius, cy - radius), xy(cx + radius, cy + radius)],
                             fill=color, outline='white', width=max(2, round(1.5 * scale)))
                font = ImageFont.truetype(str(FONT / 'Pretendard-Bold.otf'), round(radius * 1.15 * scale))
                draw.text(xy(cx, cy), str(number), font=font, fill='white', anchor='mm')
            ANNOTATED.mkdir(parents=True, exist_ok=True)
            suffix = f'-{panel + 1}' if panels > 1 else ''
            annotated_path = ANNOTATED / (screen['id'] + suffix + '.png')
            canvas.save(annotated_path)
            image = base64.b64encode(annotated_path.read_bytes()).decode('ascii')
            result.append(f'<figure><img alt="{esc(screen["caption"])}" src="data:image/png;base64,{image}">'
                          f'<figcaption>그림 {chapter}-{counter}. {esc(screen["caption"])}' + (f' ({panel + 1}/{panels})' if panels > 1 else '') + '</figcaption>')
            if descriptions:
                result.append('<table class="points"><tbody>' + ''.join(f'<tr><th>{CIRCLES[n - 1]}</th><td>{inline(points[n] if n in points else configured[n])}</td></tr>' for n in sorted(set(descriptions))) + '</tbody></table>')
            result.append('</figure>')
        missing = [p for p in screen['callouts'] if p['n'] not in {c['n'] for c in meta['callouts']}]
        if missing:
            print(f'경고: {screen["id"]}: callout 없음: ' + ', '.join(CIRCLES[p['n'] - 1] for p in missing), file=sys.stderr)
    unassigned = sorted(set(points) - described)
    if unassigned:
        print(f'경고: {chapter}장: callout이 없어 설명표에서 제외: ' + ', '.join(CIRCLES[n - 1] for n in unassigned), file=sys.stderr)
    return ''.join(result)


def chapter_html(chapter, screens):
    n, title, lines = chapter['n'], chapter['title'], chapter['lines']
    summary, body, points = [], [], {}
    in_points = False
    for line in lines:
        if line.startswith(('목적:', '언제:')):
            summary.append(line)
        elif line.strip() == '화면 포인트':
            in_points = True
            body.append('@@FIGURES@@')
        elif in_points and re.match(r'^- [①-⑩]', line):
            points[CIRCLES.index(line[2]) + 1] = line[4:]
        else:
            if line.strip():
                in_points = False
            body.append(line)
    result = (f'<section class="chapter" id="chapter-{n}"><div class="marker">MANUAL_CH_{n:02d}_START</div>'
              f'<div class="chapter-head"><div class="chapter-number">{n:02d}</div><h1>{inline(title)}</h1></div>')
    if summary:
        result += '<div class="summary">' + ''.join('<p>' + inline(s) + '</p>' for s in summary) + '</div>'
    chunks = '\n'.join(body).split('@@FIGURES@@')
    result += blocks(chunks[0].splitlines())
    if len(chunks) > 1:
        result += '<h2>화면과 포인트</h2>' + figures(n, points, screens)
        result += blocks(chunks[1].splitlines())
    elif any(s['chapter'] == n for s in screens):
        result += '<h2>화면과 포인트</h2>' + figures(n, points, screens)
    return result + '</section>'


def stylesheet():
    fonts = '\n'.join(f'@font-face{{font-family:Pretendard;src:url("{(FONT / ("Pretendard-" + face + ".otf")).as_uri()}");font-weight:{weight};}}' for face, weight in [('SemiBold', 600), ('Bold', 700), ('ExtraBold', 800)])
    return fonts + '''
@page{size:A4;margin:20mm 18mm}*{box-sizing:border-box}html{color:#181818;background:white;font-family:'Apple SD Gothic Neo',sans-serif;font-size:10.5pt;line-height:1.65;-webkit-print-color-adjust:exact;print-color-adjust:exact}body{margin:0}h1,h2,h3,.chapter-number,.wordmark{font-family:Pretendard,'Apple SD Gothic Neo',sans-serif}h1{font-size:26pt;font-weight:800;line-height:1.3;margin:0}h2{font-size:13pt;font-weight:700;margin:7mm 0 3mm;break-after:avoid}p{margin:2.5mm 0}strong{font-weight:700}code{font-family:Menlo,monospace;font-size:.92em;background:#f1f1f1;padding:0 1mm;overflow-wrap:anywhere}.cover,.front,.toc,.chapter{break-before:page}.cover{height:250mm;position:relative;padding-top:24mm;color:#1F2A44}.wordmark{font-size:30pt;letter-spacing:.3em;font-weight:600}.cover-rule{width:22mm;border-top:3px solid #C8102E;margin:30mm 0 12mm}.cover h1{font-size:40pt}.subtitle{font-size:17pt;margin-top:7mm}.edition{margin-top:24mm}.ribbon{margin-top:15mm;border-top:1px solid #222;border-bottom:1px solid #222;padding:5mm 0;font-weight:700}.cover-bottom{position:absolute;bottom:8mm;letter-spacing:.15em;font-size:9pt}.marker{font:1pt Menlo;line-height:1pt;height:1pt;color:#777}.final .marker{color:transparent}.chapter-head{display:flex;align-items:baseline;gap:6mm;border-bottom:2px solid #1F2A44;padding-bottom:7mm;margin-bottom:7mm}.chapter-number{font-size:52pt;line-height:1;color:#1F2A44;font-weight:800}.summary{border:1px solid #777;padding:4mm 5mm;margin-bottom:7mm;background:#f6f6f6}.steps{list-style:none;margin:0;padding:0}.steps li{display:flex;gap:3mm;margin:3mm 0;break-inside:avoid}.step{font-size:15pt;line-height:1.5;color:#1F2A44}.caution{border:1px solid #888;border-left:5px solid #1F2A44;padding:4mm 5mm;margin:6mm 0;break-inside:avoid;page-break-inside:avoid}.caution>b{font-family:Pretendard;font-size:11pt}table{width:100%;border-collapse:collapse;font-size:9.5pt;margin:4mm 0 7mm}th,td{border-bottom:1px solid #aaa;text-align:left;vertical-align:top;padding:3mm}thead{display:table-header-group}thead th{border-top:2px solid #1F2A44;border-bottom:1px solid #1F2A44;font-weight:700}tr{break-inside:avoid}.points{margin:2mm 0 0;font-size:10pt;line-height:1.4}.points th,.points td{padding:3.5px 6px}.points th{width:10mm;font-size:11pt}.points small{display:block;color:#555;font-size:8pt}figure{margin:5mm 0 8mm;break-inside:avoid;page-break-inside:avoid}figure img{display:block;width:auto;height:auto;max-width:100%;max-height:118mm;margin:0 auto;border:1px solid #ccc}figcaption{font-size:9pt;color:#333;margin:2mm 0;font-weight:600}.toc-row{display:flex;align-items:baseline;gap:2mm;margin:4mm 0;color:inherit;text-decoration:none}.leader{flex:1;border-bottom:1px dotted #888}.toc-number{width:9mm;font-family:Menlo}.toc-page{min-width:10mm;text-align:right;font-family:Menlo}.front h1,.toc h1{margin:5mm 0 10mm}.bullet{padding-left:3mm;text-indent:-3mm}@media screen{body{max-width:210mm;margin:10mm auto;padding:20mm 18mm;box-shadow:0 0 12px #ccc}.cover,.front,.toc,.chapter{margin-bottom:20mm}.chapter{border-top:1px solid #ccc;padding-top:10mm}}
'''


def render_html(preface, chapters, screens, pages=None):
    cover = f'''<section class="cover"><div class="wordmark">JIEUM</div><div class="cover-rule"></div><h1>운영자 매뉴얼</h1><p class="subtitle">발주 · 위챗 · 주문 운영</p><p class="edition">판 {VERSION}<br>2026-11-17</p><div class="ribbon">막히면 화면 오른쪽 아래 [의견 보내기]</div><div class="cover-bottom">JIEUM · OPERATIONS MANUAL</div></section>'''
    info = '<section class="front"><div class="marker">MANUAL_INFO_START</div><h1>문서 정보</h1>'
    info += blocks([line for line in preface.splitlines() if not line.startswith('# ')])
    info += f'<h2>판 이력</h2><table><thead><tr><th>판</th><th>날짜</th><th>내용</th></tr></thead><tbody><tr><td>{VERSION}</td><td>2026-11-17</td><td>운영 사이트 점검 반영 — 2장 저장 후 화면, 7장 입고 처리(전량·일부 입고) 정정</td></tr><tr><td>1.1</td><td>2026-11-17</td><td>장별 의견란 삭제 — 의견은 화면의 [의견 보내기]로 받음, 0장에 의견 보내기 안내 추가, 12장 삭제</td></tr><tr><td>1.0</td><td>2026-11-17</td><td>시범 운영판</td></tr></tbody></table></section>'
    toc = '<section class="toc"><div class="marker">MANUAL_TOC_START</div><h1>목차</h1>'
    for chapter in chapters:
        n = chapter['n']
        page = str(pages[f'MANUAL_CH_{n:02d}_START']) if pages else '000'
        toc += f'<a class="toc-row" href="#chapter-{n}"><span class="toc-number">{n:02d}</span><span>{inline(chapter["title"])}</span><span class="leader"></span><span class="toc-page">{page}</span></a>'
    toc += '</section>'
    return f'<!doctype html><html lang="ko"><head><meta charset="utf-8"><title>JIEUM 운영자 매뉴얼 v{VERSION}</title><style>' + stylesheet() + '</style></head><body' + (' class="final"' if pages else '') + '>' + cover + info + toc + ''.join(chapter_html(c, screens) for c in chapters) + '</body></html>'


def node_render(html_path, jobs, config_name):
    config = WORK / config_name
    config.write_text(json.dumps({'html': str(html_path), 'jobs': jobs}, ensure_ascii=False), encoding='utf-8')
    subprocess.run(['node', str(HERE / 'pdf.mjs'), str(config), VERSION], check=True)


def page_texts(pdf):
    try:
        from pypdf import PdfReader
    except ImportError:
        if not shutil.which('pdftotext'):
            raise RuntimeError('쪽 번호 추출에는 pypdf 또는 poppler의 pdftotext가 필요합니다')
        text = subprocess.run(['pdftotext', '-layout', str(pdf), '-'], check=True, capture_output=True, encoding='utf-8').stdout
        pages = text.split('\f')
        if pages and not pages[-1].strip():
            pages.pop()
        return pages
    return [page.extract_text() or '' for page in PdfReader(str(pdf)).pages]


def trim_empty_tail(pdf):
    """Drop only trailing pages with neither text nor images before mapping pages."""
    try:
        from pypdf import PdfReader, PdfWriter
    except ImportError:
        return  # CSS does not force a break after the final chapter.
    reader = PdfReader(str(pdf))
    keep = len(reader.pages)
    while keep:
        page = reader.pages[keep - 1]
        if (page.extract_text() or '').strip() or list(page.images):
            break
        keep -= 1
    if keep == len(reader.pages):
        return
    writer = PdfWriter()
    for page in reader.pages[:keep]:
        writer.add_page(page)
    temporary = pdf.with_suffix('.trimmed.pdf')
    with temporary.open('wb') as stream:
        writer.write(stream)
    writer.close()
    temporary.replace(pdf)


def merge(parts, output):
    try:
        from pypdf import PdfWriter
    except ImportError:
        if not shutil.which('pdfunite'):
            raise RuntimeError('PDF 합치기에는 pypdf 또는 poppler의 pdfunite가 필요합니다')
        subprocess.run(['pdfunite', *map(str, parts), str(output)], check=True)
        return
    writer = PdfWriter()
    for part in parts:
        writer.append(str(part), import_outline=False)
    writer.add_metadata({'/Title': f'JIEUM 운영자 매뉴얼 v{VERSION}', '/Author': 'JIEUM', '/Subject': '발주 · 위챗 · 주문 운영'})
    with output.open('wb') as stream:
        writer.write(stream)
    writer.close()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    missing_fonts = [FONT / f'Pretendard-{face}.otf' for face in ('SemiBold', 'Bold', 'ExtraBold') if not (FONT / f'Pretendard-{face}.otf').is_file()]
    if missing_fonts:
        raise RuntimeError('글꼴이 없습니다: ' + ', '.join(map(str, missing_fonts)))
    preface, chapters = parse()
    screens = json.loads((HERE / 'screens.json').read_text(encoding='utf-8'))
    first_html, first_pdf = WORK / 'pass1.html', WORK / 'pass1.pdf'
    first_html.write_text(render_html(preface, chapters, screens), encoding='utf-8')
    node_render(first_html, [{'output': str(first_pdf), 'cover': True}], 'pass1-jobs.json')
    trim_empty_tail(first_pdf)
    texts = page_texts(first_pdf)
    markers = ['MANUAL_INFO_START', 'MANUAL_TOC_START'] + [f'MANUAL_CH_{c["n"]:02d}_START' for c in chapters]
    pages = {}
    for marker in markers:
        matches = [i + 1 for i, text in enumerate(texts) if marker in re.sub(r'\s+', '', text)]
        if len(matches) != 1:
            raise RuntimeError(f'쪽 마커를 고유하게 찾지 못했습니다: {marker}: {matches}')
        pages[marker] = matches[0]
    starts = [pages[m] for m in markers]
    if starts != sorted(set(starts)):
        raise RuntimeError('장 시작 쪽 순서가 올바르지 않습니다')
    final_html = OUT / (NAME + '.html')
    final_html.write_text(render_html(preface, chapters, screens, pages), encoding='utf-8')
    jobs = [{'output': str(WORK / 'cover.pdf'), 'pages': '1', 'cover': True}]
    titles = ['문서 정보', '목차'] + [f'{c["n"]}. {c["title"]}' for c in chapters]
    for i, (start, title) in enumerate(zip(starts, titles)):
        end = starts[i + 1] - 1 if i + 1 < len(starts) else len(texts)
        jobs.append({'output': str(WORK / f'part-{i:02d}.pdf'), 'pages': f'{start}-{end}', 'title': title})
    node_render(final_html, jobs, 'pass2-jobs.json')
    final_pdf = OUT / (NAME + '.pdf')
    merge([Path(job['output']) for job in jobs], final_pdf)
    # Same-sized TOC numbers and invisible markers keep pagination stable.
    if len(page_texts(final_pdf)) != len(texts):
        raise RuntimeError('2차 렌더의 쪽 수가 변경되었습니다. 결과를 배포하지 마세요')
    (WORK / 'page-map.json').write_text(json.dumps(pages, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(final_pdf)
    print(final_html)


if __name__ == '__main__':
    main()
