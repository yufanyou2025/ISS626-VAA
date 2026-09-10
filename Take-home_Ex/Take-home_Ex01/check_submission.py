"""Structural checks for the rendered deliverables, using only Python's standard library."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote
import json
import re

base = Path(__file__).resolve().parent
root = base.parent.parent
site = root / '_site'
published = site / 'Take-home_Ex' / 'Take-home_Ex01'
report_source = (base / 'technical-report.qmd').read_text(encoding='utf-8-sig')
slides_source = (base / 'executive-summary.qmd').read_text(encoding='utf-8-sig')
assert 'PENDING' not in report_source + slides_source
assert all(f'Task {i}' in report_source for i in range(1, 7))
interpretations = re.findall(r'::: \{#(interpretation-[^}]+)\}\s*(.*?)\s*:::', report_source, re.S)
assert len(interpretations) == 6
def words(text):
    return len(re.findall(r"\b\w+(?:[’'-]\w+)*\b", text))
counts = {name: words(text) for name, text in interpretations}
assert all(n <= 150 for n in counts.values()), counts
planning = re.search(r'::: \{#planning-discussion\}\s*(.*?)\s*:::', report_source, re.S).group(1)
assert words(planning) <= 500
assert len(re.findall(r'^## ', slides_source, re.M)) == 11  # contents + 10; cover generated

class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.sections = []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ('a', 'link', 'script', 'img'):
            value = attrs.get('href') or attrs.get('src')
            if value:
                self.links.append(value)
        if tag == 'section':
            self.sections.append(attrs.get('id'))

errors = []
link_count = 0
for path in [site / 'index.html', published / 'technical-report.html', published / 'executive-summary.html']:
    parser = Page()
    parser.feed(path.read_text(encoding='utf-8'))
    if path.name == 'executive-summary.html':
        assert len(parser.sections) == 12, parser.sections
    for target in parser.links:
        url = urlsplit(target)
        if url.scheme or url.netloc or not url.path:
            continue
        relative = unquote(url.path)
        file = site / relative.lstrip('/') if relative.startswith('/') else path.parent / relative
        link_count += 1
        if not file.exists():
            errors.append(f'{path.relative_to(site)} -> {target}')
assert not errors, errors
assert not (published / 'data').exists()
assert not list(published.rglob('*.csv'))
assert not list(published.rglob('*.geojson'))
summary = json.loads((base / 'outputs/summary.json').read_text())
assert summary['study_records'] == 530 and summary['unique_locations'] == 503
assert summary['global_csr_p'] == 0.005
assert summary['missing_coordinates'] + summary['located_national'] == summary['deduplicated_records']
print(json.dumps({'status': 'PASS', 'interpretation_words': counts,
                  'planning_words': words(planning), 'slides_including_cover_contents': 12,
                  'local_references_checked': link_count,
                  'raw_data_published': False}, indent=2))
