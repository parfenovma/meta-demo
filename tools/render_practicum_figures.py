#!/usr/bin/env python3
"""Make original, labelled teaching figures from frozen histories, not solvers.

Author-only requirements: reportlab, Pillow, pdftoppm, kpsewhich and TeX's
DejaVu fonts. The ordinary notebook and documentation build don't need these.
"""
import array
import base64
import gzip
import hashlib
import json
import math
import subprocess
import sys
import zlib
from pathlib import Path

from PIL import Image
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs' / 'practicum' / 'figures'
TEMP = ROOT / 'tmp' / 'pdfs' / 'practicum-figures'
COLORS = ['#7b8d99', '#168b80', '#ca8538', '#9065af']


def setup():
    OUT.mkdir(parents=True, exist_ok=True)
    TEMP.mkdir(parents=True, exist_ok=True)
    for name, file in [('Text', 'DejaVuSans.ttf'), ('Bold', 'DejaVuSans-Bold.ttf')]:
        path = subprocess.check_output(['kpsewhich', file], text=True).strip()
        if not path:
            raise RuntimeError('Missing font: ' + file)
        pdfmetrics.registerFont(TTFont(name, path))


def load(name):
    path = ROOT / 'data' / 'canonical' / (name + '.json.gz')
    return json.loads(gzip.decompress(path.read_bytes()))


def samples(case):
    a = array.array('f')
    a.frombytes(zlib.decompress(base64.b64decode(case['values'])))
    if sys.byteorder != 'little':
        a.byteswap()
    return a


def label(c, x, y, text, size=10, color='#243d49', align='left', bold=False):
    c.setFillColor(color)
    c.setFont('Bold' if bold else 'Text', size)
    {'left': c.drawString, 'center': c.drawCentredString, 'right': c.drawRightString}[align](x, y, text)


def fmt(n):
    return (f'{n:.3f}'.rstrip('0').rstrip('.') if n and .001 <= abs(n) < 10000 else f'{n:.3g}').replace('-', '−')


def frequency_ticks(low, high):
    raw = (high-low)/4
    power = 10**math.floor(math.log10(raw))
    step = next(s for s in [1,2,2.5,5,10] if s >= raw/power)*power
    ticks = [i*step for i in range(math.ceil(low/step),math.floor(high/step)+1)]
    if ticks[0]-low > .3*step:
        ticks.insert(0,low)
    if high-ticks[-1] > .3*step:
        ticks.append(high)
    return ticks


def output(name, width, height, render):
    pdf = TEMP / (name + '.pdf')
    c = canvas.Canvas(str(pdf), pagesize=(width, height))
    c.setTitle(name + ' / frozen MetaNDT data')
    c.setFillColor('white')
    c.rect(0, 0, width, height, fill=1, stroke=0)
    render(c)
    c.save()
    subprocess.run(['pdftoppm', '-f', '1', '-l', '1', '-singlefile', '-scale-to', '1800',
                    '-png', str(pdf), str(OUT / name)], check=True)


def axes(c, box, xr, yr, xlabel, ylabel, xticks=None, yticks=None):
    x, y, w, h = box
    X = lambda v: x + (v - xr[0]) / (xr[1] - xr[0]) * w
    Y = lambda v: y + (v - yr[0]) / (yr[1] - yr[0]) * h
    xticks = xticks or [xr[0] + i * (xr[1] - xr[0]) / 4 for i in range(5)]
    yticks = yticks or [yr[0] + i * (yr[1] - yr[0]) / 4 for i in range(5)]
    c.setLineWidth(.5)
    for v in yticks:
        c.setStrokeColor('#d3dee2')
        c.line(x, Y(v), x + w, Y(v))
        label(c, x - 8, Y(v) - 3, fmt(v), 9, align='right')
    for i, v in enumerate(xticks):
        label(c, X(v), y - 17, fmt(v), 9, align='left' if i == 0 else 'right' if i == len(xticks)-1 else 'center')
    c.setStrokeColor('#95aab3')
    c.rect(x, y, w, h, fill=0, stroke=1)
    label(c, x, y + h + 12, ylabel, 10)
    label(c, x + w, y - 34, xlabel, 10, align='right')
    return X, Y


def line(c, x, y, X, Y, color, clip=None):
    c.setStrokeColor(color)
    c.setLineWidth(1.6)
    p = c.beginPath()
    connected = False
    for a, b in zip(x, y):
        if not math.isfinite(b) or (clip is not None and abs(b) >= clip):
            connected = False
            continue
        if connected:
            p.lineTo(X(a), Y(b))
        else:
            p.moveTo(X(a), Y(b))
        connected = True
    c.drawPath(p)


def frequency(name, title, series, ylabel, yr, marker, factor=1, clip=None, yticks=None, height=425):
    def render(c):
        label(c, 65, height-28, title, 16, bold=True)
        xvalues = [v * factor for v in series[0]['x']]
        xr = min(xvalues), max(xvalues)
        box = (65, 90, 625, height-160)
        if yr[0] < 0:
            c.setFillColor('#faf1df')
            c.rect(box[0], box[1], box[2], box[3] * (-yr[0]) / (yr[1] - yr[0]), fill=1, stroke=0)
        X, Y = axes(c, box, xr, yr, 'Частота, ' + ('кГц' if factor == .001 else 'Гц'), ylabel,
                    xticks=frequency_ticks(*xr), yticks=yticks)
        for j, s in enumerate(series):
            line(c, [v * factor for v in s['x']], s['y'], X, Y, COLORS[j], clip=clip)
        c.setStrokeColor('#b68a31')
        c.setDash(4, 3)
        c.line(X(marker * factor), box[1], X(marker * factor), box[1] + box[3])
        c.setDash()
        label(c, X(marker * factor) + 5, box[1] + box[3] - 17, fmt(marker * factor), 9, '#927029')
        cursor = 65
        for j, s in enumerate(series):
            c.setStrokeColor(COLORS[j])
            c.setLineWidth(2)
            c.line(cursor, 34, cursor + 18, 34)
            label(c, cursor + 24, 31, s['name'], 10)
            cursor += 24 + pdfmetrics.stringWidth(s['name'], 'Text', 10) + 24
    output(name, 720, height, render)


def wave_color(z):
    a = min(1, math.sqrt(abs(z)))
    return (15 + 239*a, 32 + 110*a, 43 + 54*a) if z >= 0 else (15 + 60*a, 32 + 132*a, 43 + 200*a)


def path_color(z):
    a = min(1, math.sqrt(max(0, z)))
    return 10 + 235*a*a, 25 + 190*a, 35 + 110*a*(1-a)


def field(c, case, values, box, limit, path=False):
    nx, ny = len(case['x']), len(case['y'])
    pixels = []
    for j in range(ny-1, -1, -1):
        for i in range(nx):
            k = j*nx + i
            if not case['valid'][k]:
                rgb = 64, 79, 87
            elif path and case['x'][i] <= case['geometry']['lens_exit']:
                rgb = 23, 42, 52
            else:
                rgb = (path_color if path else wave_color)(values[k]/limit)
            pixels.append(tuple(round(v) for v in rgb))
    image = Image.new('RGB', (nx, ny))
    image.putdata(pixels)
    x, y, w, h = box
    c.drawImage(ImageReader(image), x, y, w, h)
    X = lambda v: x + (v - case['x'][0]) / (case['x'][-1] - case['x'][0])*w
    Y = lambda v: y + (v - case['y'][0]) / (case['y'][-1] - case['y'][0])*h
    c.setStrokeColor('#c1d2d8')
    c.setLineWidth(.5)
    for outline in case['geometry'].get('outlines', []):
        p = c.beginPath()
        for i, point in enumerate(outline):
            (p.moveTo if i == 0 else p.lineTo)(X(point[0]), Y(point[1]))
        p.close()
        c.drawPath(p)
    for i in range(5):
        xx = case['x'][0] + i * (case['x'][-1] - case['x'][0])/4
        unit = 1000 if path else 1
        label(c, X(xx), y - 14, fmt(xx*unit), 8, align='center')
    for i in range(3):
        yy = case['y'][0] + i * (case['y'][-1] - case['y'][0])/2
        label(c, x - 5, Y(yy) - 3, fmt(yy*(1000 if path else 1)), 8, align='right')
    label(c, x, y + h + 9, 'y, ' + ('мм' if path else 'м'), 9)
    label(c, x+w, y - 29, 'x, ' + ('мм' if path else 'м'), 9, align='right')
    if path:
        c.setStrokeColor('#f3d57e')
        c.setLineWidth(.8)
        c.setDash(3, 3)
        focus = case['geometry']['focus']
        c.line(X(focus), y, X(focus), y+h)
        c.setDash()
        c.circle(X(focus), Y(0), 4, stroke=1, fill=0)
    return X, Y


def colorbar(c, box, limit, path=False):
    x, y, w, h = box
    for i in range(256):
        z = i/255 if path else 2*i/255-1
        rgb = (path_color if path else wave_color)(z)
        c.setFillColorRGB(*(v/255 for v in rgb))
        c.rect(x+i*w/256, y, w/256+.1, h, fill=1, stroke=0)
    for i in range(5):
        label(c, x+w*i/4, y-15, (str(i*25)+('+' if i == 4 else '')) if path else fmt(limit*(i/2-1)), 9, align='center')


def make_ground(data):
    cases = data['sets'][0]['cases']
    histories = [samples(case) for case in cases]
    limit = max(abs(v) for a in histories for v in a)
    time = .0023
    def render(c):
        label(c, 45, 323, 'После отражения: один момент, общий диапазон давления', 15, bold=True)
        for j, (case, history) in enumerate(zip(cases, histories)):
            frame = min(range(len(case['times'])), key=lambda i: abs(case['times'][i]-time))
            n = len(case['x'])*len(case['y'])
            box = (45 + 266*j, 124, 230, 143.75)
            label(c, box[0]+115, 291, ['Ровная поверхность', 'Выступ', 'Выступ под плащом'][j], 11, align='center', bold=True)
            X, Y = field(c, case, history[frame*n:(frame+1)*n], box, limit)
            if case['geometry']['variant'] == 'cloak':
                line(c, [-.168, 0, .168], [0, .112, 0], X, Y, '#e4bb66')
        colorbar(c, (190, 54, 450, 12), limit)
        label(c, 415, 15, 'Давление p, Па; t ≈ 2,3 мс. Цвет нелинейный, деления численные.', 10, align='center')
    output('04-cloak', 840, 350, render)


def accumulate(case, history):
    n = len(case['x'])*len(case['y'])
    q = array.array('d', [0])*n
    for t in range(1, len(case['times'])):
        dt = (case['times'][t]-case['times'][t-1])/2
        start, previous = t*n, (t-1)*n
        for k in range(n):
            q[k] += dt*(history[start+k]**2 + history[previous+k]**2)
    return q


def make_stg(data):
    cases = data['sets'][0]['cases']
    fields = [accumulate(case, samples(case)) for case in cases]
    limit = max(q[k] for case, q in zip(cases, fields) for k in range(len(q))
                if case['valid'][k] and case['x'][k % len(case['x'])] > case['geometry']['lens_exit']+.005)
    profiles = data['profile']['series']
    maximum = max(v for s in profiles for v in s['y'])
    def render(c):
        label(c, 45, 535, 'STG: накопленный квадрат поперечного смещения', 16, bold=True)
        for j, (case, q) in enumerate(zip(cases, fields)):
            box = (45+375*j, 300, 320, 320*.112/.18)
            label(c, box[0]+160, 514, ['Одинаковые кирпичики', 'Подобранная раскладка'][j], 11, align='center', bold=True)
            field(c, case, q, box, limit, path=True)
        colorbar(c, (190, 251, 380, 12), limit, path=True)
        label(c, 380, 217, 'Q / Qref, %; вся запись 140 мкс. Не энергия. Значения выше 100% насыщаются.', 9, align='center')
        label(c, 70, 190, 'Профили на сечении x = 39,6 мм', 11, bold=True)
        label(c, 435, 190, 'Серый: одинаковые; зелёный: раскладка', 8)
        X, Y = axes(c, (70, 55, 650, 111), (-56, 56), (0, 105), 'Координата y, мм', 'Q / Qmax профилей, %', yticks=[0,25,50,75,100])
        for j, s in enumerate(profiles):
            line(c, [v*1000 for v in s['x']], [100*v/maximum for v in s['y']], X, Y, COLORS[j])
        s = profiles[1]
        peak = max(s['y']); half = peak/2; index = s['y'].index(peak)
        left = right = index
        while left > 0 and s['y'][left] >= half:
            left -= 1
        while right < len(s['y'])-1 and s['y'][right] >= half:
            right += 1
        cross = lambda a,b: 1000*(s['x'][a]+(half-s['y'][a])/(s['y'][b]-s['y'][a])*(s['x'][b]-s['x'][a]))
        l, r = cross(left,left+1), cross(right-1,right)
        yy = Y(100*half/maximum)
        c.setStrokeColor('#b48a30'); c.setLineWidth(1)
        c.line(X(l),yy,X(r),yy)
        for xx in [X(l),X(r)]: c.line(xx,yy-4,xx,yy+4)
        label(c, (X(l)+X(r))/2, yy+7, f'{r-l:.1f} мм', 9, '#956e20', align='center')
    output('05-stg', 760, 560, render)


def main():
    setup()
    data = {name: load(name) for name in ['mass','bulk','absorber','cloak','focus']}
    def curves(name, transform=lambda y:y):
        p = data[name]['plot']
        return [dict(s, x=s.get('x',p.get('x')), y=[transform(v) for v in s['y']]) for s in p['series']]
    frequency('01-mass', 'Динамическая масса: два варианта мембраны', curves('mass'),
              'Re σeff, кг/м²; за пределами ±15 кривая не показана',
              (-16,16), 192, clip=15, yticks=[-15,-10,-5,0,5,10,15])
    frequency('02-bulk', 'Модуль канала относительно воды', curves('bulk'),
              'Re K / Kводы, без единиц; за пределами ±4 кривая не показана',
              (-4.4,4.4), data['bulk']['sets'][1]['frequency'], .001, clip=4, yticks=[-4,-2,0,1,2,4])
    frequency('03-absorption', 'Потери надо согласовать, а не просто увеличить',
              curves('absorber', lambda v:100*v), 'Поглощённая мощность, %',
              (0,105), 848, yticks=[0,25,50,75,100])
    make_ground(data['cloak'])
    make_stg(data['focus'])
    provenance = {name: {'source_digest': d['source_digest'], 'bundle_sha256': hashlib.sha256((ROOT/'data'/'canonical'/(name+'.json.gz')).read_bytes()).hexdigest()} for name,d in data.items()}
    (OUT/'provenance.json').write_text(json.dumps(provenance, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('Rendered five figures from shipped data; no physical solver invoked.')


if __name__ == '__main__':
    main()
