#!/usr/bin/env python3
"""Assemble the ordered Markdown sources; never concatenate per-chapter PDFs.

Only Python's standard library is needed. Pandoc creates standalone HTML and
XeLaTeX creates the PDF. Figures are shipped; regeneration is a separate tool.
"""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BOOK = ROOT / 'docs' / 'practicum'
LINK = re.compile(r'(!?\[[^\]\n]*\]\()([^\s)]+)(\))')
ANCHOR = re.compile(r'\{#([\w-]+)\}')


def assemble():
    config = json.loads((BOOK / 'book.json').read_text(encoding='utf-8'))
    paths = [(BOOK / name).resolve() for name in config['chapters']]
    texts = {path: path.read_text(encoding='utf-8') for path in paths}
    chapter_ids = {}
    anchors = set()
    figures = set()
    for path, text in texts.items():
        headings = re.findall(r'^# (.+)$', text, re.M)
        if len(headings) != 1 or not ANCHOR.search(headings[0]):
            raise ValueError(f'{path.name}: exactly one H1 with a stable anchor is required')
        chapter_ids[path] = ANCHOR.search(headings[0]).group(1)
        for anchor in ANCHOR.findall(text):
            if anchor in anchors:
                raise ValueError(f'Duplicate anchor: {anchor}')
            anchors.add(anchor)
        if text.startswith('---\n') or text.count('```') % 2:
            raise ValueError(f'{path.name}: front matter or unclosed code block')
        if any(token in text for token in ('__DATA__', 'turn79view', 'TODO:', 'TBD', ':codex-')):
            raise ValueError(f'{path.name}: unfinished or tool-specific content')

    def rewrite(path, match):
        start, target, end = match.groups()
        if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', target):
            return match.group(0)
        name, _, fragment = target.partition('#')
        if name:
            destination = (path.parent / name).resolve()
            if destination.suffix == '.md':
                if destination not in chapter_ids:
                    raise ValueError(f'{path.name}: linked chapter not in manifest: {target}')
                target = '#' + (fragment or chapter_ids[destination])
            elif start.startswith('!['):
                if not destination.is_file() or destination.parent != BOOK / 'figures':
                    raise ValueError(f'{path.name}: missing/nonlocal figure {target}')
                figures.add(destination)
                target = 'figures/' + destination.name
            else:
                raise ValueError(f'{path.name}: unsupported local link: {target}')
        if target.startswith('#') and target[1:] not in anchors:
            raise ValueError(f'{path.name}: unresolved anchor {target}')
        return start + target + end

    merged = '\n\n'.join(LINK.sub(lambda match: rewrite(path, match), text.strip())
                         for path, text in texts.items()) + '\n'
    merged = merged.translate(str.maketrans({'\u2011':'-', '\u2013':'-', '\u2014':'-', '\u00ad':''}))
    return config, merged, figures, paths


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--format', choices=['all', 'html', 'pdf'], default='all')
    parser.add_argument('--check', action='store_true', help='validate sources without writing outputs')
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'output' / 'pdf')
    args = parser.parse_args()
    config, merged, figures, paths = assemble()
    if args.check:
        print(f'OK: {len(paths)} chapters, {len(figures)} figures, all cross-links resolved')
        return
    if not shutil.which('pandoc'):
        raise SystemExit('Pandoc is missing. See docs/practicum/README.md.')
    if args.format in ('all', 'pdf') and not shutil.which('xelatex'):
        raise SystemExit('XeLaTeX is missing. HTML-only build: --format html')
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    (out / 'figures').mkdir(exist_ok=True)
    for figure in figures:
        shutil.copy2(figure, out / 'figures' / figure.name)
    source = out / 'metamaterials-practicum.md'
    source.write_text(merged, encoding='utf-8')
    metadata = out / 'metadata.json'
    metadata.write_text(json.dumps({k: v for k, v in config.items() if k != 'chapters'}, ensure_ascii=False), encoding='utf-8')
    base = ['pandoc', str(source), '--standalone', '--toc', '--toc-depth=1',
            '--from=markdown+tex_math_dollars+header_attributes',
            '--metadata-file=' + str(metadata), '--resource-path=' + str(out),
            '--fail-if-warnings']
    if args.format in ('all', 'html'):
        subprocess.run(base + ['--to=html5', '--mathml', '--embed-resources',
            '--css=' + str(BOOK / 'print.css'), '-o', str(out / 'metamaterials-practicum.html')], check=True, cwd=out)
    if args.format in ('all', 'pdf'):
        result = subprocess.run(base + ['--verbose', '--pdf-engine=xelatex', '--top-level-division=chapter',
            '-V', 'documentclass=report', '-V', 'papersize=a4', '-V', 'fontsize=11pt',
            '-V', 'geometry:margin=20mm', '-V', 'linestretch=1.0',
            '-V', 'mainfont=DejaVuSerif.ttf', '-V', 'sansfont=DejaVuSans.ttf',
            '-V', 'monofont=DejaVuSansMono.ttf', '-V', 'mathfont=latinmodern-math.otf',
            '-V', 'mainfontoptions=BoldFont=DejaVuSerif-Bold.ttf,ItalicFont=DejaVuSerif-Italic.ttf,BoldItalicFont=DejaVuSerif-BoldItalic.ttf',
            '-V', 'sansfontoptions=BoldFont=DejaVuSans-Bold.ttf,ItalicFont=DejaVuSans-Oblique.ttf,BoldItalicFont=DejaVuSans-BoldOblique.ttf',
            '-V', 'monofontoptions=Scale=0.85',
            '--lua-filter=' + str(BOOK / 'pagebreaks.lua'),
            '--include-in-header=' + str(BOOK / 'header.tex'),
            '-o', str(out / 'metamaterials-practicum.pdf')], cwd=out, text=True, capture_output=True)
        log = ROOT / 'tmp' / 'pdfs' / 'practicum-build.log'
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text(result.stdout + result.stderr, encoding='utf-8')
        if result.returncode:
            raise SystemExit(f'PDF build failed: inspect {log}')
        if re.search(r'Missing character:|Overfull \\[hv]box', result.stdout + result.stderr):
            raise SystemExit(f'Typesetting defect: inspect {log}')
    provenance = {'sources': {str(path.relative_to(BOOK)): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths},
                  'figures': {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in figures},
                  'formatting': {name: hashlib.sha256((BOOK / name).read_bytes()).hexdigest()
                                 for name in ('book.json', 'print.css', 'header.tex', 'pagebreaks.lua')},
                  'pandoc': subprocess.check_output(['pandoc', '--version'], text=True).splitlines()[0]}
    (out / 'build-manifest.json').write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Built in {out}')


if __name__ == '__main__':
    main()
