#!/usr/bin/env python3

"""
Enforces the system state for Quarto blog posts by treating the subfolder name
(slug) as the source of truth. It performs the following:

1.  POST DISCOVERY: Scans the 'log/' directory for subfolders (posts).
2.  FORMAT CONVERSION: Converts all JPG/PNG images to WebP and deletes originals.
3.  OG ALIGNMENT: Renames any 'og-*' image to 'og-<folder-slug>.webp'.
4.  METADATA SYNC: Ensures index.qmd frontmatter 'image' property points to
    the correct 'og-<folder-slug>.webp' file, injecting it if missing.

REQUIRES
- Pillow

python3 -m pip install Pillow

USAGE
    python3 scripts/sync-blog-assets.py             # Process all in log/
    python3 scripts/sync-blog-assets.py log/my-post # Process specific post
    python3 scripts/sync-blog-assets.py --dry-run   # Preview changes
"""

import argparse
import re
import sys
from pathlib import Path

from PIL import Image

LOG_DIR = Path("log")


class Colors:
    OK = "\033[92m"
    FIX = "\033[93m"
    ERR = "\033[91m"
    END = "\033[0m"
    BOLD = "\033[1m"


def setup_args():
    parser = argparse.ArgumentParser(description="Sync blog images and metadata.")
    parser.add_argument("path", nargs="?", default=str(LOG_DIR), help="Path to process")
    parser.add_argument("--dry-run", action="store_true", help="Don't save changes")
    return parser.parse_args()


def convert_images(folder, dry_run):
    """Converts JPG/PNG to WebP. Returns list of new webp files."""
    extensions = ("*.jpg", "*.jpeg", "*.png", "*.JPG", "*.JPEG", "*.PNG")
    found_any = False

    for ext in extensions:
        for img_path in folder.glob(ext):
            target_path = img_path.with_suffix(".webp")
            if not dry_run:
                with Image.open(img_path) as img:
                    if img.mode in ("RGBA", "P"):
                        img = img.convert("RGB")
                    img.save(target_path, "WEBP", quality=90)
                img_path.unlink()  # delete original
            found_any = True
    return found_any


def sync_assets(folder, dry_run):
    slug = folder.name
    expected_og = f"og-{slug}.webp"
    index_qmd = folder / "index.qmd"

    changes = []

    if convert_images(folder, dry_run):
        changes.append("Converted images to WebP")

    webp_files = list(folder.glob("*.webp"))
    og_candidates = [f for f in webp_files if f.name.startswith("og-")]

    if len(og_candidates) == 1:
        current_og = og_candidates[0]
        if current_og.name != expected_og:
            if not dry_run:
                current_og.rename(folder / expected_og)
            changes.append(f"Renamed {current_og.name} -> {expected_og}")
    elif len(og_candidates) > 1 and not (folder / expected_og).exists():
        return f"{Colors.ERR}[WARN]{Colors.END} Multiple 'og-' files found. Manual fix needed."

    if index_qmd.exists():
        with open(index_qmd, "r", encoding="utf-8-sig") as f:
            lines = f.readlines()

        if lines and lines[0].strip() == "---":
            end_fm = -1
            for i in range(1, len(lines)):
                if lines[i].strip() == "---":
                    end_fm = i
                    break

            if end_fm != -1:
                img_pattern = re.compile(r"^(\s*)image:\s*(.*)$")
                found = False
                new_lines = lines[:]

                for i in range(1, end_fm):
                    match = img_pattern.match(lines[i])
                    if match:
                        found = True
                        val = match.group(2).strip().strip('"').strip("'")
                        if val != expected_og:
                            new_lines[i] = f'{match.group(1)}image: "{expected_og}"\n'
                            if not dry_run:
                                with open(index_qmd, "w", encoding="utf-8") as f:
                                    f.writelines(new_lines)
                            changes.append("Updated index.qmd property")
                        break

                if not found:
                    new_lines.insert(end_fm, f'image: "{expected_og}"\n')
                    if not dry_run:
                        with open(index_qmd, "w", encoding="utf-8") as f:
                            f.writelines(new_lines)
                    changes.append("Injected missing image property")

    if not changes:
        return f"{Colors.OK}[OK]{Colors.END}   {Colors.BOLD}{slug:<30}{Colors.END} Up-to-date"
    else:
        status = " (DRY RUN)" if dry_run else ""
        return f"{Colors.FIX}[FIX]{Colors.END}  {Colors.BOLD}{slug:<30}{Colors.END} {', '.join(changes)}{status}"


def main():
    args = setup_args()
    root = Path(args.path)

    if not root.exists():
        print(f"Path {root} not found.")
        sys.exit(1)

    targets = (
        [root]
        if (root / "index.qmd").exists()
        else sorted([d for d in root.iterdir() if d.is_dir()])
    )

    print(f"🚀 Starting sync on {len(targets)} post(s)...\n")
    for target in targets:
        print(sync_assets(target, args.dry_run))


if __name__ == "__main__":
    main()
