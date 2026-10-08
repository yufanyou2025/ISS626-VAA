"""Check the rendered submission and restricted-input exclusion."""
from pathlib import Path
from urllib.parse import urlsplit, unquote
import json
import re
import subprocess
from bs4 import BeautifulSoup

root = Path(__file__).resolve().parents[2]
exercise = root / "Take-home_Ex/Take-home_Ex02"
site = root / "_site"
report = site / "Take-home_Ex/Take-home_Ex02/technical-report.html"
slides = report.with_name("executive-summary.html")
required = ["config.R", "prepare-boundaries.R", "prepare-events.R", "analysis.R",
            "methods.R", "scan.R", "visualise.R", "verify.R", "render.ps1",
            "technical-report.qmd", "executive-summary.qmd", "data/README.md"]
assert all((exercise / file).is_file() for file in required)
assert report.is_file() and slides.is_file()
words = lambda text: len(re.findall(r"\b[\w]+(?:[-'][\w]+)*\b", text))
report_soup = BeautifulSoup(report.read_text(encoding="utf-8"), "html.parser")
slide_soup = BeautifulSoup(slides.read_text(encoding="utf-8"), "html.parser")
visual_words = [words(x.get_text(" ", strip=True)) for x in report_soup.select(".interpretation")]
cluster_words = [words(x.get_text(" ", strip=True)) for x in report_soup.select(".cluster-interpretation")]
assert len(visual_words) == 9 and max(visual_words) <= 200
assert len(cluster_words) == 4 and max(cluster_words) <= 250
assert len(slide_soup.select(".slides > section")) == 12
assert len(report_soup.select("details.workflow-code")) == 7
assert "53,899" in report_soup.get_text() and "89,005" in report_soup.get_text()
broken = []
for file, soup in [(report, report_soup), (slides, slide_soup)]:
    for tag in soup.select("[href], [src]"):
        url = tag.get("href", tag.get("src", ""))
        parsed = urlsplit(url)
        if parsed.scheme or parsed.netloc or not parsed.path:
            continue
        local = (site / unquote(parsed.path.lstrip("/"))) if parsed.path.startswith("/") else (file.parent / unquote(parsed.path))
        if not local.exists():
            broken.append(f"{file.name}: {url}")
assert not broken, broken
tracked = subprocess.check_output(["git", "ls-files"], cwd=root, text=True).splitlines()
restricted = [p for p in tracked if p.startswith("Take-home_Ex/Take-home_Ex02/data/") and p != "Take-home_Ex/Take-home_Ex02/data/README.md"]
assert not restricted, restricted
published_data = site / "Take-home_Ex/Take-home_Ex02/data"
assert not published_data.exists(), "Restricted input directory copied into website"
result = {"visual_words": visual_words, "cluster_words": cluster_words,
          "slides": 12, "broken_local_links": broken, "tracked_restricted_inputs": restricted}
print(json.dumps(result, indent=2))
