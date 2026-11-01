"""Check Exercise 3's rendered deliverables, visual limits, local assets and data exclusion."""
from pathlib import Path, PurePosixPath
from urllib.parse import urlsplit, unquote
import csv
import gzip
import json
import re
import subprocess
import math
from bs4 import BeautifulSoup


ROOT = Path(__file__).resolve().parents[2]
EXERCISE = ROOT / "Take-home_Ex/Take-home_Ex03"
SITE = ROOT / "_site"
PUBLISHED = SITE / "Take-home_Ex/Take-home_Ex03"


def require(condition: bool, explanation: str) -> None:
    if not condition:
        raise AssertionError(explanation)


def forbidden(path: str) -> bool:
    parts = PurePosixPath(path).parts
    return ".git" in parts or "cache" in parts or any(
        a == "data" and b in {"raw", "processed", "boundaries"}
        for a, b in zip(parts, parts[1:]))


def words(text: str) -> int:
    return len(re.findall(r"\b[\w]+(?:[-'][\w]+)*\b", text))


def main() -> None:
    required_source = ["prepare-spatial.R", "prepare-ridership.R", "analysis.R", "methods.R",
                       "technical-report.qmd", "executive-summary.qmd", "README.md", "data/README.md",
                       "notes/ridership-provenance.md", "outputs/ridership-input-manifest.csv",
                       "outputs/station-results.csv", "outputs/origin-market-potential.csv",
                       "outputs/destination-attractions.csv", "outputs/interactions-existing.csv.gz",
                       "outputs/interactions-expanded.csv.gz", "outputs/session-info.txt"]
    for relative in required_source:
        require((EXERCISE / relative).is_file(), "Missing required source: " + relative)
    report = PUBLISHED / "technical-report.html"
    slides = PUBLISHED / "executive-summary.html"
    require(report.is_file() and slides.is_file(), "Both rendered report and slides must exist.")
    report_soup = BeautifulSoup(report.read_text(encoding="utf-8"), "html.parser")
    slides_soup = BeautifulSoup(slides.read_text(encoding="utf-8"), "html.parser")
    interpretation_words = [words(block.get_text(" ", strip=True))
                            for block in report_soup.select(".interpretation")]
    require(bool(interpretation_words), "Report needs identifiable .interpretation blocks for major visuals.")
    require(max(interpretation_words) <= 200, "A visual interpretation exceeds 200 words.")
    images = report_soup.select("main img")
    require(len(images) >= 4, "Expected substantive maps and statistical graphics in the report.")
    require(len(interpretation_words) >= len(images), "Add a concise interpretation for each main visual.")
    leaf_slides = [section for section in slides_soup.select(".slides section")
                   if not section.find("section", recursive=False)]
    cover = [section for section in leaf_slides if section.get("id") == "title-slide"]
    contents = [section for section in leaf_slides if re.search(
        r"^(contents|content|roadmap|outline)$",
        (section.find(["h1", "h2"]).get_text(" ", strip=True) if section.find(["h1", "h2"]) else ""), re.I)]
    require(len(cover) == 1, "Expected one Quarto title slide.")
    require(len(contents) <= 1, "Only one contents slide is excluded from the content-slide limit.")
    content_slides = len(leaf_slides) - len(cover) - len(contents)
    require(content_slides <= 10 and len(leaf_slides) <= 12,
            f"Slide limit exceeded: {content_slides} content slides, {len(leaf_slides)} total.")
    require(content_slides >= 6, "Slide deck is missing essential sections.")
    broken = []
    files_to_check = [report, slides]
    files_to_check.extend(PUBLISHED.glob("figures/*.html"))
    for file in files_to_check:
        soup = BeautifulSoup(file.read_text(encoding="utf-8"), "html.parser")
        for tag in soup.select("[href], [src]"):
            for attribute in ("href", "src"):
                url = tag.get(attribute)
                if not url:
                    continue
                parsed = urlsplit(url)
                if parsed.scheme or parsed.netloc or not parsed.path:
                    continue
                path = unquote(parsed.path)
                target = SITE / path.lstrip("/") if path.startswith("/") else file.parent / path
                if not target.exists():
                    broken.append(f"{file.relative_to(SITE)}: {url}")
    require(not broken, "Broken local links/assets: " + repr(broken))
    # The distributed ZIP intentionally has no .git directory. Keep HTML/data
    # checks usable there without accidentally inspecting an ancestor checkout.
    has_git_metadata = (ROOT / ".git").exists()
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0") if has_git_metadata else []
    excluded = [p for p in tracked if p and forbidden(p)]
    require(not excluded, "Raw/intermediate/cache files are tracked: " + repr(excluded))
    published_excluded = [str(p.relative_to(SITE)) for p in PUBLISHED.rglob("*")
                          if forbidden(str(p.relative_to(SITE)).replace("\\", "/"))]
    require(not published_excluded, "Raw/cache data copied into the website: " + repr(published_excluded))
    with (EXERCISE / "outputs/observed-station-ridership.csv").open(encoding="utf-8", newline="") as stream:
        observed = list(csv.DictReader(stream))
    require(len(observed) == 181 and sum(int(row["source_station_code_count"]) for row in observed) == 182,
            "Observed January aggregate must reconcile 182 source codes to 181 physical access sites.")
    require(sum(float(row["observed_monthly_tap_in"]) for row in observed) == 88683630,
            "Monthly station tap-ins do not reconcile to the frozen input.")
    require(sum(float(row["am_weekday_monthly_tap_in"]) for row in observed) == 18549493,
            "Morning station tap-ins do not reconcile to the frozen input.")
    with (EXERCISE / "outputs/origin-market-potential.csv").open(encoding="utf-8", newline="") as stream:
        origins = list(csv.DictReader(stream))
    with (EXERCISE / "outputs/station-results.csv").open(encoding="utf-8", newline="") as stream:
        stations = list(csv.DictReader(stream))
    origin_market = {row["origin_id"]: float(row["market_potential"]) for row in origins}
    require(len(origin_market) == len(origins) and all(x > 0 for x in origin_market.values()),
            "Origin identifiers must be unique and their market potential positive.")
    existing = {row["destination"] for row in stations if row["status"] == "existing"}
    expanded = {row["destination"] for row in stations}
    require(len(existing) == 181 and len(expanded) == 210 and len(stations) == 210,
            "Scenario must reconcile to 181 existing + 29 new physical sites.")
    require(sum(int(row["lines_after"]) > int(row["lines_before"]) for row in stations
                if row["status"] == "existing") == 7, "Expected seven upgraded existing interchanges.")
    market_total = sum(float(row["am_weekday_daily_tap_in"]) for row in observed)
    for column in ("fitted_daily", "expanded_daily"):
        total = sum(float(row[column]) for row in stations if row[column] not in {"", "NA"})
        require(abs(total - market_total) < 1e-5, "Scenario market is not conserved: " + column)
    compressed = sorted((EXERCISE / "outputs").glob("*.csv.gz"))
    # Read the complete interaction frames to check their pair keys, numerical
    # fields and per-origin probability conservation independently of R objects.
    compressed_rows = {}
    for file in compressed:
        with gzip.open(file, "rt", encoding="utf-8", newline="") as stream:
            reader = csv.DictReader(stream)
            if file.name not in {"interactions-existing.csv.gz", "interactions-expanded.csv.gz"}:
                compressed_rows[file.name] = sum(1 for _ in reader)
                continue
            required_columns = {"origin_id", "destination", "market_potential", "lines", "attraction", "distance", "p_ij"}
            require(required_columns <= set(reader.fieldnames or []), "Interaction schema incomplete: " + file.name)
            destinations = existing if file.name == "interactions-existing.csv.gz" else expanded
            seen = {key: set() for key in origin_market}
            sums = {key: 0.0 for key in origin_market}
            count = 0
            for row in reader:
                origin, destination = row["origin_id"], row["destination"]
                require(origin in seen and destination in destinations,
                        "Interaction pair contains an unknown identifier.")
                require(destination not in seen[origin], "Repeated origin/destination pair.")
                seen[origin].add(destination)
                distance, probability = float(row["distance"]), float(row["p_ij"])
                require(math.isfinite(distance) and distance >= 0 and math.isfinite(probability)
                        and 0 <= probability <= 1, "Invalid interaction distance or probability.")
                require(abs(float(row["market_potential"]) - origin_market[origin]) < 1e-6,
                        "Interaction frame changes the origin's market potential.")
                require(float(row["attraction"]) > 0 and float(row["lines"]) >= 1,
                        "Interaction attraction/line count must be positive.")
                sums[origin] += probability
                count += 1
            require(all(len(values) == len(destinations) for values in seen.values()),
                    "Interaction frame does not contain every origin/destination pair.")
            require(max(abs(total - 1) for total in sums.values()) < 1e-8,
                    "Interaction probabilities do not sum to one per origin.")
            compressed_rows[file.name] = count
    result = {"report_images": len(images), "interpretation_words": interpretation_words,
              "content_slides": content_slides, "total_slides": len(leaf_slides),
              "broken_local_links": broken, "tracked_excluded_inputs": excluded,
              "published_excluded_inputs": published_excluded, "observed_stations": len(observed),
              "tracked_git_check": "passed" if has_git_metadata else "not applicable: unpacked submission has no .git",
              "origins": len(origins), "expanded_stations": len(stations),
              "compressed_output_rows": compressed_rows}
    encoded = json.dumps(result, indent=2) + "\n"
    (EXERCISE / "outputs/submission-checks.json").write_text(encoded, encoding="utf-8")
    print(encoded, end="")


if __name__ == "__main__":
    main()
