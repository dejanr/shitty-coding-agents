#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  tracker.sh [--file FILE] mark --episode S02E06 [--through]
  tracker.sh [--file FILE] refresh

Options:
  --file FILE   Tracker markdown file (default: breaking-bad.md)
EOF
}

normalize_episode() {
  local raw normalized
  raw="${1:-}"
  normalized="$(printf '%s' "$raw" | tr '[:lower:]' '[:upper:]' | tr -d ' ')"

  if [[ "$normalized" =~ ^S([0-9]{1,2})E([0-9]{1,2})$ ]]; then
    printf 'S%02dE%02d' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi

  if [[ "$normalized" =~ ^([0-9]{1,2})[XE]([0-9]{1,2})$ ]]; then
    printf 'S%02dE%02d' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi

  printf 'Invalid episode format: %s. Use S02E05 or 2x05\n' "$raw" >&2
  return 1
}

tracker_file="breaking-bad.md"
command=""
episode=""
through=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      [[ $# -ge 2 ]] || { echo "Missing value for --file" >&2; exit 1; }
      tracker_file="$2"
      shift 2
      ;;
    mark|refresh)
      command="$1"
      shift
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$command" in
  mark)
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --episode)
          [[ $# -ge 2 ]] || { echo "Missing value for --episode" >&2; exit 1; }
          episode="$2"
          shift 2
          ;;
        --through)
          through=1
          shift
          ;;
        --show)
          [[ $# -ge 2 ]] || { echo "Missing value for --show" >&2; exit 1; }
          shift 2
          ;;
        *)
          echo "Unknown mark argument: $1" >&2
          usage >&2
          exit 1
          ;;
      esac
    done

    [[ -n "$episode" ]] || { echo "--episode is required for mark" >&2; exit 1; }
    ;;
  refresh)
    [[ $# -eq 0 ]] || { echo "refresh does not take extra arguments" >&2; exit 1; }
    ;;
  *)
    echo "Missing command (mark|refresh)" >&2
    usage >&2
    exit 1
    ;;
esac

if [[ ! -f "$tracker_file" ]]; then
  echo "Tracker file not found: $(cd "$(dirname "$tracker_file")" && pwd)/$(basename "$tracker_file")" >&2
  exit 1
fi

if [[ "$command" == "mark" ]]; then
  normalized_episode="$(normalize_episode "$episode")"
fi

tmp_file="$(mktemp)"
summary_file="$(mktemp)"

cleanup() {
  rm -f "$tmp_file" "$summary_file"
}
trap cleanup EXIT

awk \
  -v mode="$command" \
  -v target_episode="${normalized_episode:-}" \
  -v through="$through" \
  -v summary_file="$summary_file" '
function trim(s) {
  sub(/^[[:space:]]+/, "", s)
  sub(/[[:space:]]+$/, "", s)
  return s
}

function set_error(msg) {
  if (error == "") {
    error = msg
  }
  return 0
}

function parse_episode_line(line) {
  if (!match(line, /^- \[([x ])\] (S[0-9][0-9]E[0-9][0-9]) — (.*) \((.*)\)$/, parts)) {
    return 0
  }

  g_mark = parts[1]
  g_code = parts[2]
  g_title = parts[3]
  g_air = parts[4]
  return 1
}

function collect_episodes(   i) {
  delete ep_line
  delete ep_code
  delete ep_title
  delete ep_air
  delete ep_watched
  ep_count = 0

  for (i = 1; i <= n; i++) {
    if (!parse_episode_line(lines[i])) {
      continue
    }

    ep_count++
    ep_line[ep_count] = i
    ep_code[ep_count] = g_code
    ep_title[ep_count] = g_title
    ep_air[ep_count] = g_air
    ep_watched[ep_count] = (g_mark == "x") ? 1 : 0
  }

  if (ep_count == 0) {
    return set_error("No episode checklist lines found. Expected lines like: - [x] S02E06 — Peekaboo (April 12, 2009)")
  }

  return 1
}

function rewrite_episodes(   i, mark) {
  for (i = 1; i <= ep_count; i++) {
    mark = ep_watched[i] ? "x" : " "
    lines[ep_line[i]] = "- [" mark "] " ep_code[i] " — " ep_title[i] " (" ep_air[i] ")"
  }
}

function compute_stats(   i) {
  total = ep_count
  watched = 0
  remaining = 0
  progress = 0
  last_watched = "—"
  next_episode = "Completed"

  for (i = 1; i <= ep_count; i++) {
    if (ep_watched[i]) {
      watched++
      last_watched = ep_code[i] " — " ep_title[i]
    } else if (next_episode == "Completed") {
      next_episode = ep_code[i] " — " ep_title[i]
    }
  }

  remaining = total - watched
  if (total > 0) {
    progress = (watched * 100.0) / total
  }
}

function replace_summary(prefix, value,   i) {
  for (i = 1; i <= n; i++) {
    if (index(lines[i], prefix) == 1) {
      lines[i] = prefix value
      return 1
    }
  }
  return set_error("Summary line not found: " prefix)
}

function update_summary() {
  if (!replace_summary("- Total episodes: ", total)) {
    return 0
  }
  if (!replace_summary("- Watched: ", watched)) {
    return 0
  }
  if (!replace_summary("- Remaining: ", remaining)) {
    return 0
  }
  if (!replace_summary("- Progress: ", sprintf("%.1f%%", progress))) {
    return 0
  }
  if (!replace_summary("- Last watched: ", last_watched)) {
    return 0
  }
  if (!replace_summary("- Next episode: ", next_episode)) {
    return 0
  }

  return 1
}

function mark_episode(   i, target_index) {
  if (!collect_episodes()) {
    return 0
  }

  target_index = 0
  for (i = 1; i <= ep_count; i++) {
    if (ep_code[i] == target_episode) {
      target_index = i
      break
    }
  }

  if (target_index == 0) {
    return set_error("Episode " target_episode " not found")
  }

  if (through == "1") {
    for (i = 1; i <= target_index; i++) {
      ep_watched[i] = 1
    }
  } else {
    ep_watched[target_index] = 1
  }

  rewrite_episodes()
  compute_stats()

  if (!update_summary()) {
    return 0
  }

  print watched "|" total "|" sprintf("%.1f", progress) "|" next_episode > summary_file
  close(summary_file)
  return 1
}

function refresh_tracker() {
  if (!collect_episodes()) {
    return 0
  }

  compute_stats()
  if (!update_summary()) {
    return 0
  }

  print watched "|" total "|" sprintf("%.1f", progress) "|" next_episode > summary_file
  close(summary_file)
  return 1
}

{
  n++
  lines[n] = $0
}

END {
  if (mode == "mark") {
    if (!mark_episode()) {
      print error > "/dev/stderr"
      exit 1
    }
  } else if (mode == "refresh") {
    if (!refresh_tracker()) {
      print error > "/dev/stderr"
      exit 1
    }
  } else {
    print "Unknown command: " mode > "/dev/stderr"
    exit 1
  }

  for (i = 1; i <= n; i++) {
    print lines[i]
  }
}
' "$tracker_file" > "$tmp_file"

mv "$tmp_file" "$tracker_file"

IFS='|' read -r watched total progress next_episode < "$summary_file"
printf 'Updated Breaking Bad: watched %s/%s (%s%%), next: %s\n' "$watched" "$total" "$progress" "$next_episode"
