"""Package only our addon sources and documentation, never installed addon data."""
from pathlib import Path
import re
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
addon = root / "OpenMapDungeonRoutes"
version = re.search(r"^## Version: (\S+)$", (addon / "OpenMapDungeonRoutes.toc").read_text(encoding="utf-8"), re.MULTILINE).group(1)
out = root / "dist" / f"OpenMapDungeonRoutes-{version}.zip"
out.parent.mkdir(exist_ok=True)
with ZipFile(out, "w", ZIP_DEFLATED) as archive:
    for path in sorted(addon.iterdir()):
        if path.is_file() and path.suffix in {".lua", ".toc"}:
            archive.write(path, path.relative_to(root))
    for name in ("LICENSE", "README.md", "CHANGELOG.md"):
        archive.write(root / name, f"OpenMapDungeonRoutes/{name}")
print(out)
