#!/bin/bash
#
# Performs validation checks for the lopes.id repository.
#
# USAGE
# This script is executed automatically by Git via the pre-commit hook.
# Do NOT run directly. To install the hook: ./scripts/setup.sh

#!/bin/bash
set -u

MAX_POST_FILENAME_LEN=50
MAX_DECK_SLUG_LEN=50
MAX_TITLE_LEN=60
MAX_DESCRIPTION_LEN=160
MAX_IMAGE_FILENAME_LEN=70
MAX_IMAGE_FILESIZE=307200 # 300 KB

POSTS_DIR="log"
DECKS_DIR="decks"
IMAGES_DIR="static/images"

error=0

if stat -c "%s" . >/dev/null 2>&1; then
  STAT_CMD='stat -c "%s"'
else
  STAT_CMD='stat -f "%z"'
fi

# Read a top-level YAML front-matter value from $file. Strips inline `# ...`
# comments on unquoted values, trims whitespace, and unquotes single/double
# quotes. Single-line values only (matches original behavior).
get_yaml_val() {
  local key="$1"
  local raw
  raw="$(grep -E "^$key:" "$file" | head -1 | sed "s/$key: *//")"
  # Strip inline comment only if value isn't a quoted literal (# is legal inside quotes).
  if [[ "$raw" != \"* && "$raw" != \'* ]]; then
    raw="${raw%%#*}"
  fi
  # Trim, then unquote.
  raw="$(echo "$raw" | xargs)"
  raw="${raw#\"}"; raw="${raw%\"}"
  raw="${raw#\'}"; raw="${raw%\'}"
  echo "$raw"
}

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
    echo "🔍 Standalone mode: Checking all files in $POSTS_DIR, $DECKS_DIR, and $IMAGES_DIR..."
    FILES_TO_CHECK=$(find "$POSTS_DIR" "$DECKS_DIR" "$IMAGES_DIR" -type f 2>/dev/null)
else
    echo "🔍 Git hook mode: Checking staged files..."
    FILES_TO_CHECK="$STAGED_FILES"
fi

while IFS= read -r file; do
  [[ -z "$file" || ! -f "$file" ]] && continue

  # ---- POSTS (.qmd) ----
  if [[ "$file" == "$POSTS_DIR"/*.qmd && "$file" != *"/"_* ]]; then
    filename=$(basename "$file")

    if [ ${#filename} -gt $MAX_POST_FILENAME_LEN ]; then
      echo "ERROR: $file filename too long (${#filename})"
      error=1
    fi

    title=$(get_yaml_val "title")
    desc=$(get_yaml_val "description")
    image=$(get_yaml_val "image")

    if [[ -z "$title" ]]; then
      echo "ERROR: $file missing title"
      error=1
    elif [ ${#title} -gt $MAX_TITLE_LEN ]; then
      echo "ERROR: $file title too long (${#title} chars)"
      error=1
    fi

    if [[ -z "$desc" ]]; then
      echo "ERROR: $file missing description"
      error=1
    elif [ ${#desc} -gt $MAX_DESCRIPTION_LEN ]; then
      echo "ERROR: $file description too long (${#desc} chars)"
      error=1
    fi

    if [[ -z "$image" ]]; then
      echo "ERROR: $file missing 'image' field"
      error=1
    elif [[ "$image" != *.webp ]]; then
      echo "ERROR: $file image reference must be .webp"
      error=1
    elif [[ ! -f "$(dirname "$file")/$image" ]]; then
      echo "ERROR: $file image '$image' not found at $(dirname "$file")/$image"
      error=1
    fi
  fi

  # ---- DECKS (decks/<slug>/index.qmd) ----
  # Same shape as posts + deck-specific: tlp field, vigil-reveal theme path.
  # This is the ONLY gate on publishability — there is no runtime filter.
  # Non-publishable TLP (amber/red) is rejected here so it never enters the repo.
  if [[ "$file" == "$DECKS_DIR"/*/index.qmd && "$file" != *"/"_* ]]; then
    slug=$(basename "$(dirname "$file")")

    if [ ${#slug} -gt $MAX_DECK_SLUG_LEN ]; then
      echo "ERROR: $file deck slug too long (${#slug} chars, max $MAX_DECK_SLUG_LEN)"
      error=1
    fi

    title=$(get_yaml_val "title")
    desc=$(get_yaml_val "description")
    image=$(get_yaml_val "image")
    tlp=$(get_yaml_val "tlp" | tr '[:upper:]' '[:lower:]')

    if [[ -z "$title" ]]; then
      echo "ERROR: $file missing title"
      error=1
    elif [ ${#title} -gt $MAX_TITLE_LEN ]; then
      echo "ERROR: $file title too long (${#title} chars)"
      error=1
    fi

    if [[ -z "$desc" ]]; then
      echo "ERROR: $file missing description"
      error=1
    elif [ ${#desc} -gt $MAX_DESCRIPTION_LEN ]; then
      echo "ERROR: $file description too long (${#desc} chars)"
      error=1
    fi

    if [[ -z "$image" ]]; then
      echo "ERROR: $file missing 'image' field"
      error=1
    elif [[ "$image" != *.webp ]]; then
      echo "ERROR: $file image reference must be .webp"
      error=1
    elif [[ ! -f "$(dirname "$file")/$image" ]]; then
      echo "ERROR: $file image '$image' not found at $(dirname "$file")/$image"
      error=1
    fi

    if [[ -z "$tlp" ]]; then
      echo "ERROR: $file missing 'tlp' field (deck classification required)"
      error=1
    else
      case "$tlp" in
        clear|white|green) ;;
        amber|amber+strict|red)
          echo "ERROR: $file tlp '$tlp' is not publishable on lopes.id. This repo is public — sensitive material belongs in a separate private repo."
          error=1
          ;;
        *)
          echo "ERROR: $file tlp '$tlp' not one of clear|white|green"
          error=1
          ;;
      esac
    fi

    # Belt-and-suspenders theme check: the deck's format.revealjs.theme must
    # reference one of the two vigil-reveal SCSS files (light or dark).
    if ! grep -qE 'vigil-reveal-(light|dark)\.scss' "$file"; then
      echo "ERROR: $file must reference vigil-reveal-{light,dark}.scss in format.revealjs.theme"
      error=1
    fi
  fi

  # ---- Non-deck Markdown inside decks/<slug>/ must be _-prefixed ----
  # Quarto renders any .md/.qmd it finds; anything not the deck's index.qmd
  # would leak to the public site (e.g. brief.md → brief.html). Underscore
  # prefix is Quarto's convention for "partial / skip render."
  if [[ "$file" == "$DECKS_DIR"/*/*.md ]]; then
    filename=$(basename "$file")
    if [[ "$filename" != _* ]]; then
      echo "ERROR: $file arbitrary .md inside a deck folder must be _-prefixed (e.g. _NOTES.md) so Quarto doesn't render it"
      error=1
    fi
  fi

  # ---- Escape-hatch HTML — must live at decks/<slug>/assets/<name>.html ----
  # No arbitrary HTML at deck top level (that's the render's job, not a source file).
  # bash `*` in [[ == ]] matches `/`, so parse path parts explicitly.
  # Exception: underscore-prefixed support dirs at the decks/ root (Quarto's
  # "don't render" convention) hold Pandoc template partials — e.g.
  # decks/_partials/title-slide.html — not escape-hatch iframe apps.
  if [[ "$file" == "$DECKS_DIR"/* && "$file" == *.html ]]; then
    rel="${file#"$DECKS_DIR"/}"
    IFS='/' read -ra parts <<< "$rel"
    if [[ "${parts[0]}" != _* ]] && { [[ ${#parts[@]} -ne 3 ]] || [[ "${parts[1]}" != "assets" ]]; }; then
      echo "ERROR: $file escape-hatch HTML must live at decks/<slug>/assets/<name>.html"
      error=1
    fi
  fi

  # ---- IMAGES ----
  if [[ "$file" =~ \.(webp|jpg|jpeg|png|gif|svg|ico)$ ]]; then
    filename=$(basename "$file")

    if [ ${#filename} -gt $MAX_IMAGE_FILENAME_LEN ]; then
      echo "ERROR: $file filename too long"
      error=1
    fi

    size=$(eval $STAT_CMD "\"$file\"")
    if [ "$size" -gt "$MAX_IMAGE_FILESIZE" ]; then
      kb_size=$((size / 1024))
      echo "ERROR: $file is too large (${kb_size}KB). Max 300KB."
      error=1
    fi
  fi
done <<< "$FILES_TO_CHECK"

# ---- RESULT ----
if [ $error -eq 1 ]; then
  echo "❌ Validation failed. Fix errors above."
  exit 1
else
  echo "✅ All checks passed."
fi
