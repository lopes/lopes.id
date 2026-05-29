#!/bin/bash
#
# Performs validation checks for the lopes-logbook repository.
#
# USAGE
# This script is executed automatically by Git via the pre-commit hook.
# Do NOT run directly. To install the hook: ./scripts/setup.sh

#!/bin/bash
set -u

MAX_POST_FILENAME_LEN=50
MAX_TITLE_LEN=60
MAX_DESCRIPTION_LEN=160
MAX_IMAGE_FILENAME_LEN=70
MAX_IMAGE_FILESIZE=307200 # 300 KB

POSTS_DIR="log"
IMAGES_DIR="static/images"

error=0

if stat -c "%s" . >/dev/null 2>&1; then
  STAT_CMD='stat -c "%s"'
else
  STAT_CMD='stat -f "%z"'
fi

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
    echo "🔍 Standalone mode: Checking all files in $POSTS_DIR and $IMAGES_DIR..."
    FILES_TO_CHECK=$(find "$POSTS_DIR" "$IMAGES_DIR" -type f 2>/dev/null)
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

    get_yaml_val() {
      grep -E "^$1:" "$file" | head -1 | sed "s/$1: *//" | xargs | sed 's/^"//;s/"$//'
    }

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
