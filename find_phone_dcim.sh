#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: find_phone_dcim.sh [--dry-run] [--debug] [--mode=range|mtime] <YYYY-MM-DD> [OUTDIR]

Options:
  --dry-run          List files only, don't copy.
  --debug            Print detected mounts, DCIM dirs, and decisions.
  --mode=range       Match by date range [DATE, DATE+1). (default; robust)
  --mode=mtime       Match by file mtime calendar date equals DATE.

Args:
  YYYY-MM-DD         Target date (required).
  OUTDIR             Output root (default: $HOME/Downloads). Files go to OUTDIR/DATE.

Scans:
  1) DCIM/Camera                  (photos + videos)
  2) DCIM/*360*                   (photos + videos)
  3) */recordings*                (mp3 only)

Mount sources:
  - /media/$USER/*, /run/media/$USER/*
  - /run/user/$UID/gvfs/*         (GVFS MTP, e.g., Android phones)

Brand filter:
  Tries to prefer mounts whose last path segment contains a top phone brand
  (apple/iphone, samsung/galaxy, huawei, xiaomi/mi/redmi, google/pixel, oppo,
   oneplus, vivo, realme, sony/xperia, asus/zenfone, nokia, motorola/moto, nothing).
  If none match, falls back to any mount containing a DCIM directory.
EOF
}

# -------------------- parse args --------------------
DRY_RUN=0
DEBUG=0
MODE="range"   # default
ARGS=()

for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --debug)   DEBUG=1 ;;
    --mode=range) MODE="range" ;;
    --mode=mtime) MODE="mtime" ;;
    -h|--help) usage; exit 0 ;;
    *) ARGS+=("$a") ;;
  esac
done

if [[ ${#ARGS[@]} -lt 1 ]]; then usage; exit 1; fi
TARGET_DATE="${ARGS[0]}"
OUTDIR="${ARGS[1]:-$HOME/Downloads}"

# Validate date
if ! date -d "$TARGET_DATE" +%F >/dev/null 2>&1; then
  echo "Invalid date: $TARGET_DATE" >&2
  exit 1
fi
NEXT_DATE="$(date -d "$TARGET_DATE +1 day" +%F)"

DEST="$OUTDIR/$TARGET_DATE"
mkdir -p "$DEST"

# -------------------- config --------------------
PHOTO_EXT=("jpg" "jpeg" "png" "heic" "heif" "dng" "cr2" "nef" "arw" "rw2")
VIDEO_EXT=("mp4" "mov" "m4v" "3gp" "avi" "hevc" "mts" "m2ts")
BRANDS=("iphone" "apple" "samsung" "galaxy" "huawei" "xiaomi" "mi" "redmi" "google" "pixel" "oppo" "oneplus" "vivo" "realme" "sony" "xperia" "asus" "zenfone" "nokia" "motorola" "moto" "nothing")

log() { (( DEBUG )) && echo "[DEBUG] $*"; }

# mtime-date-equality check (for MODE=mtime)
is_date_match_mtime() {
  local f="$1"
  local fdate
  fdate=$(date -d @"$(stat -c %Y "$f")" +%F)
  [[ "$fdate" == "$TARGET_DATE" ]]
}

maybe_copy() {
  local f="$1"
  if (( DRY_RUN )); then
    echo "[DRY] $f"
  else
    echo "Copy -> $DEST : $f"
    cp -n -- "$f" "$DEST/"
  fi
}

# -------------------- collect mounts --------------------
CANDIDATES=()

# standard removable storage mounts
for base in "/media/$USER" "/run/media/$USER"; do
  [[ -d "$base" ]] || continue
  while IFS= read -r -d '' d; do CANDIDATES+=("$d"); done < <(find "$base" -mindepth 1 -maxdepth 1 -type d -print0)
done

# GVFS (MTP phones show here)
GVFS="/run/user/$UID/gvfs"
if [[ -d "$GVFS" ]]; then
  while IFS= read -r -d '' d; do CANDIDATES+=("$d"); done < <(find "$GVFS" -mindepth 1 -maxdepth 1 -type d -print0)
fi

if (( DEBUG )); then
  echo "[DEBUG] Mount candidates (raw):"
  if (( ${#CANDIDATES[@]} )); then
    printf '  - %s\n' "${CANDIDATES[@]}"
  else
    echo "  <none>"
  fi
fi

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo "No phone mount points found."; exit 1
fi

# Prefer mounts whose basename contains a brand keyword; else keep those with a DCIM directory
PREFERRED=()
FALLBACK=()

for m in "${CANDIDATES[@]}"; do
  bname=$(basename "$m")
  lbname="${bname,,}"   # to lowercase
  hit=0
  for kw in "${BRANDS[@]}"; do
    if [[ "$lbname" == *"$kw"* ]]; then hit=1; break; fi
  done
  if (( hit )); then
    PREFERRED+=("$m")
  else
    # fallback if it has a DCIM directory somewhere shallow (root/DCIM or root/*/DCIM)
    if [[ -d "$m/DCIM" ]] || find "$m" -mindepth 2 -maxdepth 2 -type d -iname "DCIM" -quit 2>/dev/null; then
      FALLBACK+=("$m")
    fi
  fi
done

# Final mounts list
MOUNTS=()
if (( ${#PREFERRED[@]} )); then
  MOUNTS=("${PREFERRED[@]}")
else
  MOUNTS=("${FALLBACK[@]}")
fi

if (( DEBUG )); then
  echo "[DEBUG] Chosen mounts:"
  if (( ${#MOUNTS[@]} )); then
    printf '  - %s\n' "${MOUNTS[@]}"
  else
    echo "  <none>"
  fi
fi

if [[ ${#MOUNTS[@]} -eq 0 ]]; then
  echo "No suitable mounts (no brand match and no DCIM found)."; exit 1
fi

# Build time predicate for find (only used in MODE=range)
FIND_TIME=()
if [[ "$MODE" == "range" ]]; then
  FIND_TIME=( -newermt "$TARGET_DATE" ! -newermt "$NEXT_DATE" )
fi

# -------------------- scanning --------------------
scan_root() {
  local root="$1"
  log "Scanning root: $root"

  # discover DCIM roots: root/DCIM and root/*/DCIM (GVFS often nests storage like "Internal shared storage")
  mapfile -d '' DCIMS < <(
    { [[ -d "$root/DCIM" ]] && printf '%s\0' "$root/DCIM"; } || true
    find "$root" -mindepth 2 -maxdepth 2 -type d -iname "DCIM" -print0 2>/dev/null || true
  )

  if (( DEBUG )); then
    echo "[DEBUG] DCIM dirs under $root:"
    for d in "${DCIMS[@]:-}"; do echo "  - $d"; done
  fi

  # 1) DCIM/Camera (photos + videos)
  for d in "${DCIMS[@]:-}"; do
    local cam="$d/Camera"
    if [[ -d "$cam" ]]; then
      log "Camera dir: $cam"
      if [[ "$MODE" == "range" ]]; then
        while IFS= read -r -d '' f; do
          maybe_copy "$f"
        done < <(find "$cam" -type f \( \
                    -iregex '.*\.\(jpg\|jpeg\|png\|heic\|heif\|dng\|cr2\|nef\|arw\|rw2\|mp4\|mov\|m4v\|3gp\|avi\|hevc\|mts\|m2ts\)' \
                 \) "${FIND_TIME[@]}" -print0 2>/dev/null)
      else
        while IFS= read -r -d '' f; do
          if is_date_match_mtime "$f"; then maybe_copy "$f"; fi
        done < <(find "$cam" -type f -print0 2>/dev/null)
      fi
    fi
  done

  # 2) DCIM/*360* (photos + videos)
  for d in "${DCIMS[@]:-}"; do
    while IFS= read -r -d '' sub; do
      log "360 dir: $sub"
      if [[ "$MODE" == "range" ]]; then
        while IFS= read -r -d '' f; do
          maybe_copy "$f"
        done < <(find "$sub" -type f \( \
                    -iregex '.*\.\(jpg\|jpeg\|png\|heic\|heif\|dng\|cr2\|nef\|arw\|rw2\|mp4\|mov\|m4v\|3gp\|avi\|hevc\|mts\|m2ts\)' \
                 \) "${FIND_TIME[@]}" -print0 2>/dev/null)
      else
        while IFS= read -r -d '' f; do
          if is_date_match_mtime "$f"; then maybe_copy "$f"; fi
        done < <(find "$sub" -type f -print0 2>/dev/null)
      fi
    done < <(find "$d" -type d -iname "*360*" -print0 2>/dev/null || true)
  done

  # 3) */recordings* (mp3 only)
  while IFS= read -r -d '' rec; do
    log "recordings dir: $rec"
    if [[ "$MODE" == "range" ]]; then
      while IFS= read -r -d '' f; do
        maybe_copy "$f"
      done < <(find "$rec" -type f -iname '*.mp3' "${FIND_TIME[@]}" -print0 2>/dev/null)
    else
      while IFS= read -r -d '' f; do
        if is_date_match_mtime "$f"; then maybe_copy "$f"; fi
      done < <(find "$rec" -type f -iname '*.mp3' -print0 2>/dev/null)
    fi
  done < <(find "$root" -type d -iname "*recordings*" -print0 2>/dev/null || true)
}

for m in "${MOUNTS[@]}"; do
  echo "Scanning mount: $m"
  scan_root "$m"
done

echo "Done. Files copied to $DEST"

