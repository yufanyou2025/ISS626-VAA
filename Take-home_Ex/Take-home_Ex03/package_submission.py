"""Package the committed website plus its licensed, hash-verified source snapshots.

Run this only after the final source and rendered files are committed:
    python Take-home_Ex/Take-home_Ex03/package_submission.py
"""
from pathlib import Path, PurePosixPath
import argparse
import csv
import hashlib
import json
import subprocess
import sys
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[2]
EXERCISE = "Take-home_Ex/Take-home_Ex03"
PREFIX = "ISS626-VAA/"
DEFAULT_DESTINATION = ROOT.parent / "Singapore_Rail_Takehome3_Project.zip"
REQUIRED = {
    "_quarto.yml", "ISS626-VAA.Rproj",
    f"{EXERCISE}/technical-report.qmd", f"{EXERCISE}/executive-summary.qmd",
    f"{EXERCISE}/analysis.R", f"{EXERCISE}/methods.R",
    f"{EXERCISE}/prepare-spatial.R", f"{EXERCISE}/prepare-ridership.R",
    f"{EXERCISE}/README.md", f"{EXERCISE}/data/README.md",
    f"{EXERCISE}/SUBMISSION.md", f"{EXERCISE}/check_submission.py",
    f"{EXERCISE}/outputs/observed-station-ridership.csv",
    f"{EXERCISE}/outputs/ridership-input-manifest.csv",
    f"{EXERCISE}/outputs/spatial-input-manifest.csv",
    f"{EXERCISE}/data/reference/hdb_street_codes.csv",
    f"{EXERCISE}/data/reference/LICENSE.md",
    f"{EXERCISE}/outputs/origin-market-potential.csv",
    f"{EXERCISE}/outputs/destination-attractions.csv",
    f"{EXERCISE}/outputs/interactions-existing.csv.gz",
    f"{EXERCISE}/outputs/interactions-expanded.csv.gz",
    f"_site/{EXERCISE}/technical-report.html",
    f"_site/{EXERCISE}/executive-summary.html",
}
SUPPLEMENTAL_RAW = {
    "HDBExistingBuilding.geojson", "HDBPropertyInformation.csv",
    "TrainStation_Sep2026.zip", "operational_and_future_stations.csv",
    "transport_node_train_202601.csv",
}


def git(*arguments: str) -> str:
    return subprocess.check_output(["git", *arguments], cwd=ROOT, text=True).strip()


def forbidden(path: str) -> bool:
    parts = PurePosixPath(path).parts
    return (".git" in parts or "cache" in parts or
            any(a == "data" and b in {"raw", "processed", "boundaries"}
                for a, b in zip(parts, parts[1:])) or
            path.lower().endswith((".zip", ".7z", ".rar")))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def input_snapshots() -> list[dict]:
    """Only named, licensed source files can supplement the committed inventory."""
    output = ROOT / EXERCISE / "outputs"
    records = {}
    for filename in ("spatial-input-manifest.csv", "ridership-input-manifest.csv"):
        with (output / filename).open(encoding="utf-8", newline="") as stream:
            for row in csv.DictReader(stream):
                if row["file"] in SUPPLEMENTAL_RAW:
                    records[row["file"]] = {
                        "path": f"{EXERCISE}/data/raw/{row['file']}",
                        "sha256": row["sha256"], "bytes": int(row["bytes"]),
                        "licence": row.get("licence", ""),
                        "source_url": row.get("source_url", row.get("url", "")),
                        "recorded_in": f"{EXERCISE}/outputs/{filename}",
                    }
    if set(records) != SUPPLEMENTAL_RAW:
        raise SystemExit("Source manifest does not exactly cover the permitted raw-file whitelist.")
    for record in records.values():
        file = ROOT / record["path"]
        if not file.is_file() or file.stat().st_size != record["bytes"] or sha256(file) != record["sha256"]:
            raise SystemExit("Source snapshot does not match its committed manifest: " + record["path"])
        if "Singapore Open Data Licence" not in record["licence"]:
            raise SystemExit("Source licence needs review before local redistribution: " + record["path"])
    # The sixth primary snapshot, the CC-BY street bridge, is already tracked.
    # Its reference attribution is included by git archive, so no duplicate raw
    # copy or unrelated exploratory downloads are needed in the package.
    with (output / "spatial-input-manifest.csv").open(encoding="utf-8", newline="") as stream:
        bridge = next(row for row in csv.DictReader(stream) if row["file"] == "hdb_street_codes.csv")
    if sha256(ROOT / EXERCISE / "data/reference/hdb_street_codes.csv") != bridge["sha256"]:
        raise SystemExit("Tracked street-code bridge does not match the source manifest.")
    return [records[name] for name in sorted(records)]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", type=Path, default=DEFAULT_DESTINATION)
    parser.add_argument("--revision", help="Expected full or abbreviated final HEAD revision")
    args = parser.parse_args()
    if not (ROOT / ".git").exists() or Path(git("rev-parse", "--show-toplevel")).resolve() != ROOT:
        raise SystemExit("Create packages from the original Git checkout; the distributed ZIP has no Git metadata.")
    revision = git("rev-parse", "HEAD")
    if args.revision and git("rev-parse", args.revision) != revision:
        raise SystemExit("Requested revision is not the current committed HEAD.")
    # A clean index and worktree make ls-files an accurate inventory of HEAD.
    subprocess.run(["git", "diff", "--exit-code", "HEAD", "--"], cwd=ROOT,
                   check=True, stdout=subprocess.DEVNULL)
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode("utf-8").split("\0")
    tracked = sorted(p for p in tracked if p)
    disallowed = [p for p in tracked if forbidden(p)]
    if disallowed:
        raise SystemExit("Remove restricted/cache/archive files from Git before packaging: " + repr(disallowed))
    missing = sorted(REQUIRED - set(tracked))
    if missing:
        raise SystemExit("Required deliverables are not committed: " + repr(missing))
    snapshots = input_snapshots()
    subprocess.run([sys.executable, str(ROOT / EXERCISE / "check_submission.py")],
                   cwd=ROOT, check=True)
    destination = args.destination.resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Git archive writes the committed blobs, not possibly changing working files.
    # Build beside the destination and replace only after CRC/content verification.
    with tempfile.TemporaryDirectory(prefix="rail-submission-", dir=destination.parent) as directory:
        temporary = Path(directory) / "project.zip"
        subprocess.run(["git", "archive", "--format=zip", f"--prefix={PREFIX}",
                        f"--output={temporary}", revision], cwd=ROOT, check=True)
        with zipfile.ZipFile(temporary, "a", compression=zipfile.ZIP_DEFLATED) as archive:
            archive.writestr(PREFIX + "PACKAGE_REVISION.txt", revision + "\n")
            for record in snapshots:
                archive.write(ROOT / record["path"], PREFIX + record["path"])
        with zipfile.ZipFile(temporary) as archive:
            if archive.testzip() is not None:
                raise SystemExit("Submission ZIP failed its CRC integrity check.")
            names = archive.namelist()
            files = {p for p in names if not p.endswith("/")}
            supplements = {PREFIX + record["path"] for record in snapshots}
            expected = {PREFIX + p for p in tracked} | {PREFIX + "PACKAGE_REVISION.txt"} | supplements
            if files != expected:
                raise SystemExit("ZIP inventory differs from tracked files: " +
                                 repr({"missing": sorted(expected-files), "extra": sorted(files-expected)}))
            if any(not p.startswith(PREFIX) or (forbidden(p) and p not in supplements) for p in names):
                raise SystemExit("ZIP contains an unsafe or excluded path.")
            for record in snapshots:
                check = hashlib.sha256()
                with archive.open(PREFIX + record["path"]) as stream:
                    for block in iter(lambda: stream.read(1024 * 1024), b""):
                        check.update(block)
                if check.hexdigest() != record["sha256"]:
                    raise SystemExit("A packaged snapshot differs from its recorded input hash.")
            if archive.read(PREFIX + "PACKAGE_REVISION.txt").decode().strip() != revision:
                raise SystemExit("ZIP revision marker does not match HEAD.")
        temporary.replace(destination)
    manifest = {
        "file": str(destination), "revision": revision,
        "branch": git("branch", "--show-current"), "tracked_files": len(tracked),
        "archive_files": len(files), "bytes": destination.stat().st_size,
        "sha256": sha256(destination), "top_level_folder": "ISS626-VAA",
        "integrity": "ZIP CRC, exact committed-file inventory and licensed supplemental source hashes verified",
        "supplemental_inputs": snapshots,
        "inputs": "Five licensed raw snapshots supplement the exact committed revision for offline analysis. "
                  "The sixth primary input, the attributed CC-BY street bridge, and the official address "
                  "verification reference are already tracked. Caches and unrelated downloads are excluded. "
                  "Required R packages, Quarto and optional online basemap tiles are separate dependencies.",
        "submission": "Local package only; no eLearn upload is performed by this script.",
    }
    destination.with_suffix(".manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
