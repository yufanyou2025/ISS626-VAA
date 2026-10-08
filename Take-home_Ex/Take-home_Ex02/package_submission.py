"""Archive the completed, committed project without private input directories."""
from pathlib import Path
import hashlib
import json
import subprocess
import zipfile

root = Path(__file__).resolve().parents[2]
destination = root.parent / "Myanmar_Conflict_Takehome2_Project.zip"
revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
files = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode().split("\0")
files = [p for p in files if p]
prefix = "ISS626-VAA/"
private = "Take-home_Ex/Take-home_Ex02/data/"
assert not any(p.startswith(private) and p != private + "README.md" for p in files)
assert "_site/Take-home_Ex/Take-home_Ex02/technical-report.html" in files
assert "_site/Take-home_Ex/Take-home_Ex02/executive-summary.html" in files
subprocess.run(["git", "diff", "--exit-code", "HEAD", "--", "Take-home_Ex/Take-home_Ex02", "_site/Take-home_Ex/Take-home_Ex02"], cwd=root, check=True, stdout=subprocess.DEVNULL)
with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for relative in files:
        path = root / relative
        if path.is_file():
            archive.write(path, prefix + relative)
    archive.writestr(prefix + "PACKAGE_REVISION.txt", revision + "\n")
with zipfile.ZipFile(destination) as archive:
    assert archive.testzip() is None
    contents = archive.namelist()
    assert all(p.startswith(prefix) for p in contents)
    assert not any("/.git/" in p or "/data/raw/" in p or "/data/processed/" in p for p in contents)
    for file in ["_quarto.yml", "ISS626-VAA.Rproj", "Take-home_Ex/Take-home_Ex02/analysis.R",
                 "Take-home_Ex/Take-home_Ex02/data/README.md",
                 "_site/Take-home_Ex/Take-home_Ex02/technical-report.html",
                 "_site/Take-home_Ex/Take-home_Ex02/executive-summary.html"]:
        assert prefix + file in contents
manifest = {"file": str(destination), "revision": revision, "files": len(contents),
            "bytes": destination.stat().st_size,
            "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
            "restricted_inputs": "excluded; obtain the ACLED input from eLearn and MIMU input using the documented source"}
destination.with_suffix(".manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print(json.dumps(manifest, indent=2))
