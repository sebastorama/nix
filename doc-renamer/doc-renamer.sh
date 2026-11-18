#!/usr/bin/env bash
# Move bank receipts and slaughterhouse settlements from Downloads to the
# doc_renamer inbox, then run Claude on the inbox. Downloads can have PDFs or
# images (PNG, JPEG). The inbox gets only PDFs.
#
# launchd starts this script on each change in Downloads or in the inbox, and
# runs only one copy at a time (see default.nix).
#
# Required environment: DOWNLOADS_DIR, INBOX_DIR, PROJECT_DIR.
# default.nix creates the inbox, the output folder and the log folder.
set -euo pipefail

QUIET_SECONDS=30
MIN_TEXT_CHARS=50
MAX_PAGES=3
OCR_DPI=200
LOG_RETENTION_DAYS=30

LOG_DIR="$PROJECT_DIR/logs"
FAILED_DIR="$INBOX_DIR/failed"
ORIGINALS_DIR="$INBOX_DIR/originals"
# One line for each file that stays in Downloads: "size|mtime|name".
SEEN_FILE="$PROJECT_DIR/.downloads-seen"

# `.{1,2}` matches an accented letter with or without a UTF-8 locale.
SETTLEMENT_WORDS='acerto de compra de gado|romaneio de abate|resumo de abate'
RECEIPT_WORD='comprovante'
RECEIPT_CONTEXT='pix|transfer.{1,2}ncia|pagamento|boleto|benefici.{1,2}rio|favorecido'

log() {
  local log_file
  log_file="$LOG_DIR/watch-$(date +%Y-%m-%d).log"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$log_file"
}

delete_old_logs() {
  find "$LOG_DIR" -name 'watch-*.log' -mtime "+$LOG_RETENTION_DAYS" -delete
}

# Prints the PDFs at the top level of a directory, NUL-separated.
list_pdfs() {
  find "$1" -maxdepth 1 -type f -iname '*.pdf' -print0 | sort -z
}

# Prints the PDFs and images at the top level of Downloads, NUL-separated.
list_downloads() {
  find "$DOWNLOADS_DIR" -maxdepth 1 -type f \
    \( -iname '*.pdf' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
    -print0 | sort -z
}

is_image() {
  local lowercase_name="${1,,}"
  [[ "$lowercase_name" != *.pdf ]]
}

seen_key() {
  local size_and_mtime
  size_and_mtime=$(stat -c '%s|%Y' "$1")
  echo "$size_and_mtime|$(basename "$1")"
}

is_seen() {
  [[ -f "$SEEN_FILE" ]] || return 1
  grep -qxF -- "$1" "$SEEN_FILE"
}

downloads_has_unseen_file() {
  local file
  while IFS= read -r -d '' file; do
    if ! is_seen "$(seen_key "$file")"; then
      return 0
    fi
  done < <(list_downloads)
  return 1
}

inbox_has_pdf() {
  local first_pdf
  first_pdf=$(list_pdfs "$INBOX_DIR" | head -z -n 1 | tr -d '\0')
  [[ -n "$first_pdf" ]]
}

has_work() {
  inbox_has_pdf || downloads_has_unseen_file
}

seconds_since_last_change() {
  local downloads_changed inbox_changed last_change now
  downloads_changed=$(stat -c %Y "$DOWNLOADS_DIR")
  inbox_changed=$(stat -c %Y "$INBOX_DIR")
  last_change=$downloads_changed
  if (( inbox_changed > last_change )); then
    last_change=$inbox_changed
  fi
  now=$(date +%s)
  echo $(( now - last_change ))
}

# A directory changes when a file is added, removed or renamed in it. Browsers
# rename the file when a download ends, so a long download restarts the count.
wait_for_quiet() {
  local quiet_for remaining
  while true; do
    quiet_for=$(seconds_since_last_change)
    if (( quiet_for >= QUIET_SECONDS )); then
      return
    fi
    remaining=$(( QUIET_SECONDS - quiet_for ))
    sleep "$remaining"
  done
}

ocr_text() {
  local pdf="$1"
  local work_dir image
  work_dir=$(mktemp -d)
  pdftoppm -r "$OCR_DPI" -l "$MAX_PAGES" -png "$pdf" "$work_dir/page" 2>/dev/null || true
  for image in "$work_dir"/page*.png; do
    [[ -f "$image" ]] || continue
    tesseract "$image" - -l por 2>/dev/null || true
  done
  rm -rf "$work_dir"
}

# Keywords can be split across lines, so the text is matched as one line.
one_line() {
  tr -s '[:space:]' ' '
}

# Prints the text of the first pages on one line. Uses OCR for scanned PDFs.
pdf_text() {
  local pdf="$1"
  local text
  text=$(pdftotext -l "$MAX_PAGES" "$pdf" - 2>/dev/null | one_line || true)
  if (( ${#text} < MIN_TEXT_CHARS )); then
    text=$(ocr_text "$pdf" | one_line)
  fi
  echo "$text"
}

image_text() {
  tesseract "$1" - -l por 2>/dev/null | one_line || true
}

document_text() {
  local file="$1"
  if is_image "$file"; then
    image_text "$file"
    return
  fi
  pdf_text "$file"
}

is_wanted_document() {
  local text
  text=$(document_text "$1")
  if grep -aqiE "$SETTLEMENT_WORDS" <<< "$text"; then
    return 0
  fi
  if ! grep -aqiE "$RECEIPT_WORD" <<< "$text"; then
    return 1
  fi
  grep -aqiE "$RECEIPT_CONTEXT" <<< "$text"
}

# Prints a path in the directory that no file uses: "name.pdf", "name (1).pdf", ...
free_path() {
  local dir="$1" name="$2"
  local stem="${name%.*}" extension="${name##*.}"
  local candidate="$dir/$name"
  local counter=1
  while [[ -e "$candidate" ]]; do
    candidate="$dir/$stem ($counter).$extension"
    counter=$(( counter + 1 ))
  done
  echo "$candidate"
}

move_to() {
  local pdf="$1" dir="$2"
  local target
  target=$(free_path "$dir" "$(basename "$pdf")")
  mv -- "$pdf" "$target"
  log "Moved: $pdf -> $target"
}

# The doc_renamer project reads only PDFs, so the image becomes a PDF with a
# text layer. The original image goes to ORIGINALS_DIR/YYYY-MM-DD.
convert_image_to_inbox() {
  local image="$1"
  local pdf_name pdf_path originals_today
  pdf_name="$(basename "${image%.*}").pdf"
  pdf_path=$(free_path "$INBOX_DIR" "$pdf_name")
  # tesseract adds ".pdf" to the output path.
  tesseract "$image" "${pdf_path%.pdf}" -l por pdf 2>/dev/null
  log "Converted: $image -> $pdf_path"
  originals_today="$ORIGINALS_DIR/$(date +%Y-%m-%d)"
  mkdir -p "$originals_today"
  move_to "$image" "$originals_today"
}

send_to_inbox() {
  local file="$1"
  if is_image "$file"; then
    convert_image_to_inbox "$file"
    return
  fi
  move_to "$file" "$INBOX_DIR"
}

# Sends wanted files to the inbox and records the others as seen.
# The first run only records the files that are already in Downloads.
triage_downloads() {
  local first_run=no
  if [[ ! -f "$SEEN_FILE" ]]; then
    first_run=yes
    log "First run: recording the files already in Downloads. No triage."
  fi

  local still_in_downloads file key
  still_in_downloads=$(mktemp)
  while IFS= read -r -d '' file; do
    key=$(seen_key "$file")
    if [[ "$first_run" == yes ]] || is_seen "$key"; then
      echo "$key" >> "$still_in_downloads"
      continue
    fi
    if is_wanted_document "$file"; then
      send_to_inbox "$file"
      continue
    fi
    log "Ignored: $file"
    echo "$key" >> "$still_in_downloads"
  done < <(list_downloads)
  mv -- "$still_in_downloads" "$SEEN_FILE"
}

run_claude() {
  # The inbox also holds output/, failed/ and originals/. Claude must not touch them.
  local prompt="Process the PDF files at the top level of the $INBOX_DIR folder according to CLAUDE.md instructions. Do not process files in its subfolders."
  local output exit_code=0
  output=$(
    cd "$PROJECT_DIR" && claude \
      --print \
      --dangerously-skip-permissions \
      --no-session-persistence \
      --model sonnet \
      --max-budget-usd 1.00 \
      "$prompt" 2>&1
  ) || exit_code=$?
  log "Claude exited with code $exit_code."
  log "$output"
}

# Prints how many of the given files are still in their place.
count_remaining() {
  local count=0 pdf
  for pdf in "$@"; do
    if [[ -f "$pdf" ]]; then
      count=$(( count + 1 ))
    fi
  done
  echo "$count"
}

# A PDF that stays in the inbox would start Claude again on each run.
set_aside_unprocessed() {
  local pdf
  for pdf in "$@"; do
    [[ -f "$pdf" ]] || continue
    mkdir -p "$FAILED_DIR"
    log "WARNING: Claude did not process $pdf"
    move_to "$pdf" "$FAILED_DIR"
  done
}

# A click on the notification opens the inbox, which shows output/ and failed/.
notify_result() {
  local processed_count="$1" failed_count="$2"
  local message="Processed: $processed_count."
  if (( failed_count > 0 )); then
    message="$message Failed: $failed_count (see failed/)."
  fi
  terminal-notifier -title "doc-renamer" -message "$message" \
    -open "file://$INBOX_DIR/" >/dev/null 2>&1 || log "WARNING: notification failed."
}

process_inbox() {
  local batch=()
  mapfile -d '' -t batch < <(list_pdfs "$INBOX_DIR")
  if (( ${#batch[@]} == 0 )); then
    return
  fi
  log "Invoking Claude for ${#batch[@]} PDF(s)."
  run_claude

  local failed_count processed_count
  failed_count=$(count_remaining "${batch[@]}")
  processed_count=$(( ${#batch[@]} - failed_count ))
  set_aside_unprocessed "${batch[@]}"
  notify_result "$processed_count" "$failed_count"
}

main() {
  delete_old_logs

  # A file can arrive while Claude runs, so check again after each batch.
  while has_work; do
    wait_for_quiet
    triage_downloads
    process_inbox
  done
}

main
