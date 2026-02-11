#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# daily.sh
#
# Summarizes Git commits by sending them to OpenAI GPT-3.5.
# Fetches commits from 18:00 (6 PM) of the previous day until now.
#
# Usage:
#   ./daily.sh
#   git config --global alias.daily '!~/projects/scripts/daily.sh'
#   git daily
# -----------------------------------------------------------------------------

set -euo pipefail

###############################################################################
# Global Variables
###############################################################################
AUTHOR_NAME="Julio Lima"
API_KEY="${OPENAI_API_KEY}"  # Ensure this env var is set
MODEL="gpt-3.5-turbo"

###############################################################################
# Function: usage
###############################################################################
usage() {
  cat <<EOF
Usage: $(basename "$0") [day^N | --print-range]

Examples:
  $(basename "$0") day^1         # Range: yesterday 00:00 to today 00:00
  $(basename "$0") day^2         # Range: two full previous days
  $(basename "$0") --print-range # Prints range and exits (for testing)

Environment Variables:
  OPENAI_API_KEY  Your OpenAI API key (required).
EOF
  exit 1
}

###############################################################################
# Function: is_gnu_date
# Detects if the environment has GNU date (Linux) or BSD date (macOS).
###############################################################################
is_gnu_date() {
  date --version >/dev/null 2>&1
}

###############################################################################
# Function: parse_day_arg
# Parses input like "day^N" and returns N (defaults to 1).
###############################################################################
parse_day_arg() {
  local arg="$1"
  local days=0

  if [[ "$arg" =~ ^day\^([0-9]+)$ ]]; then
    days="${BASH_REMATCH[1]}"
  elif [[ "$arg" == "day" ]]; then
    days=1
  else
    days=0
  fi

  echo "$days"
}

###############################################################################
# Function: get_full_day_range
# Given N, returns a 24h window for that specific past day.
# For N=1 → [yesterday 00:00, today 00:00)       — 24h
# For N=2 → [2 days ago 00:00, yesterday 00:00)  — 24h
# For N=3 → [3 days ago 00:00, 2 days ago 00:00) — 24h
###############################################################################
get_full_day_range() {
  local days="$1"
  local days_end=$(( days - 1 ))

  if is_gnu_date; then
    local since_time
    local until_time
    since_time=$(date -d "${days} days ago 00:00" "+%Y-%m-%dT%H:%M:%S")
    until_time=$(date -d "${days_end} days ago 00:00" "+%Y-%m-%dT%H:%M:%S")
    echo "$since_time" "$until_time"
  else
    # macOS BSD date
    local since_date
    local until_date
    since_date=$(date -v-"${days}"d "+%Y-%m-%d")
    until_date=$(date -v-"${days_end}"d "+%Y-%m-%d")
    echo "${since_date}T00:00:00" "${until_date}T00:00:00"
  fi
}

###############################################################################
# Function: get_default_range
# Returns the original default range: from 18:00 of the previous day until now.
###############################################################################
get_default_range() {
  if is_gnu_date; then
    local since_time
    since_time=$(date -d "yesterday 18:00" "+%Y-%m-%dT%H:%M:%S")
    local until_time
    until_time=$(date "+%Y-%m-%dT%H:%M:%S")
    echo "$since_time" "$until_time"
  else
    local since_date
    since_date=$(date -v-1d "+%Y-%m-%d")
    local until_time
    until_time=$(date "+%Y-%m-%dT%H:%M:%S")
    echo "${since_date}T18:00:00" "$until_time"
  fi
}

###############################################################################
# Function: fetch_commits
###############################################################################
fetch_commits() {
  local author="$1"
  local since_time="$2"
  local until_time="$3"

  git --no-pager log --author="$author" \
    --since="$since_time" \
    --until="$until_time" \
    --pretty=format:"- %h %s"
}

###############################################################################
# Function: call_openai
###############################################################################
call_openai() {
  local commits="$1"
  local api_key="$2"
  local model="$3"

  local json_payload
  json_payload=$(jq -n \
  --arg model "$MODEL" \
  --arg prompt "Summarize these Git commits into a concise bullet-point report:\n\n$commits" \
  '{model: $model, messages: [{role: "system", content: "You are a software engineer working as frontender, doing things using Next.JS. Summarizes Git commit logs into concise reports. You work at Tolq.com, a company of translation assisted by humans and AI."}, {role: "user", content: $prompt}], temperature: 0.1}')

  curl -s -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $api_key" \
    -d "$json_payload" \
  | jq -r '.choices[0].message.content'
}

###############################################################################
# Function: main
###############################################################################
main() {
  local print_range=false
  local day_arg=""

  # Parse all arguments
  for arg in "$@"; do
    case "$arg" in
      --print-range) print_range=true ;;
      day*) day_arg="$arg" ;;
      --help|-h) usage ;;
    esac
  done

  local days
  days=$(parse_day_arg "${day_arg}")

  local since_time
  local until_time
  if [[ "${days}" -gt 0 ]]; then
    read since_time until_time < <(get_full_day_range "${days}")
  else
    read since_time until_time < <(get_default_range)
  fi

  if [[ "$print_range" == true ]]; then
    echo "Range → ${since_time} .. ${until_time}"
    exit 0
  fi

  # Ensure API key is set before calling OpenAI
  if [[ -z "$API_KEY" ]]; then
    echo "Error: OPENAI_API_KEY is not set or is empty."
    echo "Tip: use '--print-range' to test date ranges without the API key."
    exit 1
  fi

  echo "💻 Fetching commits from $since_time to $until_time:"

  local commits
  commits=$(fetch_commits "$AUTHOR_NAME" "$since_time" "$until_time")

  if [[ -z "$commits" ]]; then
    echo "💻 No commits found in the given range."
    exit 0
  fi

  echo "💻 Commits found:"
  echo "$commits"
  echo

  echo "💻 Sending commits to AI for summarization..."

  echo ""
  echo "All quiet on the western front 💣🪖:"

  local summary
  summary=$(call_openai "$commits" "$API_KEY" "$MODEL")

  echo
  echo "$summary"
  echo
}

# -----------------------------------------------------------------------------
# Run main
# -----------------------------------------------------------------------------
main "$@"
