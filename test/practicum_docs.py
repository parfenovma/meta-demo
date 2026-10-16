"""Authoring regressions. Standard library only; no solver or LaTeX needed."""
import gzip
import hashlib
import importlib.util
import json
import re
import unittest
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('build_practicum', ROOT/'tools'/'build_practicum.py')
book = importlib.util.module_from_spec(spec)
spec.loader.exec_module(book)


class HTML(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = []
        self.links = []
        self.images = []
        self.math = 0
        self.titles = 0

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if 'id' in a: self.ids.append(a['id'])
        if tag == 'a': self.links.append(a.get('href',''))
        if tag == 'img': self.images.append(a)
        if tag == 'math': self.math += 1
        if tag == 'title': self.titles += 1


class Practicum(unittest.TestCase):
    def test_ordered_complete_sources(self):
        config, merged, figures, paths = book.assemble()
        self.assertEqual(len(paths), 13)
        self.assertGreater(len(merged.split()), 10000)
        self.assertEqual(len(figures), 5)
        self.assertEqual(len(re.findall(r'^# ', merged, re.M)), 13)
        for path in paths[3:8]:
            text = path.read_text(encoding='utf-8')
            self.assertGreater(len(text.split()), 650)
            self.assertGreater(len(re.findall(r'^\d+\. ', text, re.M)), 12)
            self.assertIn('## Цель и результат', text)
            self.assertIn('references.md#ref-', text)
            self.assertIn('![' ,text)
        self.assertNotRegex(merged, r'\]\([^)]*\.md(?:#|\))')
        self.assertNotIn('\u2011',merged)

    def test_figure_provenance(self):
        provenance = json.loads((book.BOOK/'figures'/'provenance.json').read_text())
        self.assertEqual(set(provenance), {'mass','bulk','absorber','cloak','focus'})
        for name, source in provenance.items():
            raw = (ROOT/'data'/'canonical'/(name+'.json.gz')).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),source['bundle_sha256'])
            self.assertEqual(json.loads(gzip.decompress(raw))['source_digest'],source['source_digest'])

    def test_launch_guide_matches_entrypoint(self):
        readme = (ROOT/'README.md').read_text()
        start = (ROOT/'start.jl').read_text()
        self.assertIn('canonical_experiments.jl',start)
        self.assertGreaterEqual(readme.count('julia +1.10 --startup-file=no --project=. start.jl'),2)
        self.assertIn('juliaup add 1.10',readme)
        self.assertIn('meta-ndt',readme)
        self.assertIn('macOS',readme)
        self.assertIn('Windows',readme)
        self.assertIn('чистая Windows-установка',readme)

    def test_built_html_has_resolved_links_and_offline_math(self):
        path = ROOT/'output'/'pdf'/'metamaterials-practicum.html'
        self.assertTrue(path.is_file(),'Build the handbook before release verification')
        html = HTML()
        html.feed(path.read_text(encoding='utf-8'))
        self.assertEqual(len(html.ids),len(set(html.ids)),'duplicate anchors after assembly')
        self.assertEqual(html.titles,1)
        for href in html.links:
            if href.startswith('#'): self.assertIn(href[1:],html.ids)
        self.assertEqual(len(html.images),5)
        for image in html.images:
            self.assertTrue(image.get('src','').startswith('data:image/png;base64,'))
            self.assertGreater(len(image.get('alt','')),20)
        self.assertGreater(html.math,40)

    def test_built_manifest_matches_current_sources(self):
        manifest = json.loads((ROOT/'output'/'pdf'/'build-manifest.json').read_text())
        _, _, figures, paths = book.assemble()
        self.assertEqual(manifest['sources'], {
            str(path.relative_to(book.BOOK)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in paths})
        self.assertEqual(manifest['figures'], {
            path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in figures})
        for name, digest in manifest['formatting'].items():
            self.assertEqual(digest,hashlib.sha256((book.BOOK/name).read_bytes()).hexdigest())


if __name__ == '__main__':
    unittest.main()
