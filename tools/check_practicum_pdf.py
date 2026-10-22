#!/usr/bin/env python3
"""Check the handbook's actual PDF page budget. Requires pypdf."""
import argparse
import json
import re
from pathlib import Path

from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[1]


def check_pdf(path):
    reader = PdfReader(path)
    sections = [item for item in reader.outline if not isinstance(item, list)]
    if len(sections) != 13:
        raise ValueError(f'Expected 13 top-level sections, got {len(sections)}')
    labs = []
    for index, section in enumerate(sections):
        match = re.match(r'^Работа ([1-5])\.', section.title)
        if not match:
            continue
        start = reader.get_destination_page_number(section)
        end = reader.get_destination_page_number(sections[index + 1])
        count = end - start
        if not 2 <= count <= 3:
            raise ValueError(f'{section.title}: {count} pages, expected 2-3')
        labs.append({'number': int(match[1]), 'first_page': start + 1,
                     'last_page': end, 'pages': count})
    if [lab['number'] for lab in labs] != list(range(1, 6)):
        raise ValueError('Expected all five labs in order')

    # Links must resolve to real pages, not merely exist as annotations.
    page_ids = {page.indirect_reference.idnum for page in reader.pages}
    named = reader.named_destinations
    internal = external = images = 0
    for index, page in enumerate(reader.pages):
        if not (page.extract_text() or '').strip():
            raise ValueError(f'Empty page {index + 1}')
        images += len(page.images)
        for ref in page.get('/Annots', []):
            annotation = ref.get_object()
            destination = annotation.get('/Dest')
            action = annotation.get('/A', {})
            if action:
                action = action.get_object()
            if action.get('/S') == '/GoTo':
                destination = action.get('/D')
            if destination is not None:
                destination = destination.get_object()
                if isinstance(destination, str):
                    if destination not in named:
                        raise ValueError(f'Missing PDF destination: {destination}')
                    target = reader.get_destination_page_number(named[destination])
                    if target is None or not 0 <= target < len(reader.pages):
                        raise ValueError(f'Invalid PDF destination: {destination}')
                elif not destination or getattr(destination[0], 'idnum', None) not in page_ids:
                    raise ValueError(f'Invalid page link on page {index + 1}')
                internal += 1
            elif action.get('/S') == '/URI':
                external += 1
    if images != 5:
        raise ValueError(f'Expected five figures, got {images}')
    return {'pages': len(reader.pages), 'labs': labs, 'figures': images,
            'internal_links': internal, 'external_links': external}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pdf', nargs='?', type=Path,
                        default=ROOT/'output'/'pdf'/'metamaterials-practicum.pdf')
    args = parser.parse_args()
    print(json.dumps(check_pdf(args.pdf), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
