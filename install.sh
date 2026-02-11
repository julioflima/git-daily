#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# git-daily installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/julioflima/git-daily/main/install.sh | bash
# -----------------------------------------------------------------------------

set -euo pipefail

REPO_URL="https://github.com/julioflima/git-daily.git"
INSTALL_DIR="$HOME/.git-daily"

###############################################################################
# Function: info / warn / error
###############################################################################
info()  { printf "\033[1;34m▸\033[0m %s\n" "$1"; }
ok()    { printf "\033[1;32m✔\033[0m %s\n" "$1"; }
ask()   { printf "\033[1;35m?\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33m⚠\033[0m %s\n" "$1"; }
error() { printf "\033[1;31m✖\033[0m %s\n" "$1" >&2; exit 1; }

###############################################################################
# Function: copy_to_clipboard
# Cross-platform clipboard copy (macOS + Linux).
###############################################################################
copy_to_clipboard() {
  local text="$1"
  if command -v pbcopy >/dev/null 2>&1; then
    echo "$text" | pbcopy
  elif command -v xclip >/dev/null 2>&1; then
    echo "$text" | xclip -selection clipboard
  elif command -v xsel >/dev/null 2>&1; then
    echo "$text" | xsel --clipboard --input
  elif command -v wl-copy >/dev/null 2>&1; then
    echo "$text" | wl-copy
  else
    return 1
  fi
}

###############################################################################
# Function: detect_shell_rc
# Detects the user's shell config file.
###############################################################################
detect_shell_rc() {
  local user_shell
  user_shell=$(basename "${SHELL:-/bin/bash}")

  case "$user_shell" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash)
      if [[ -f "$HOME/.bashrc" ]]; then
        echo "$HOME/.bashrc"
      elif [[ -f "$HOME/.bash_profile" ]]; then
        echo "$HOME/.bash_profile"
      fi
      ;;
    *)    echo "" ;;
  esac
}

###############################################################################
# Function: check_dependencies
###############################################################################
check_dependencies() {
  local missing=()
  for cmd in git curl jq bash; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing required tools: ${missing[*]}. Please install them first."
  fi
  ok "All dependencies found (git, curl, jq, bash)"
}

###############################################################################
# Function: install_repo
###############################################################################
install_repo() {
  if [[ -d "$INSTALL_DIR" ]]; then
    info "Updating existing installation..."
    git -C "$INSTALL_DIR" pull --quiet
    ok "Updated git-daily"
  else
    info "Cloning git-daily..."
    git clone --quiet "$REPO_URL" "$INSTALL_DIR"
    ok "Installed to $INSTALL_DIR"
  fi
  chmod +x "$INSTALL_DIR/daily.sh"
}

###############################################################################
# Function: setup_alias
###############################################################################
setup_alias() {
  local current
  current=$(git config --global alias.daily 2>/dev/null || echo "")

  if [[ -n "$current" ]]; then
    ask "Git alias 'daily' already exists: $current"
    printf "   Overwrite? [Y/n] "
    read -r answer </dev/tty
    if [[ "$answer" =~ ^[Nn]$ ]]; then
      info "Skipped alias setup"
      return
    fi
  fi

  git config --global alias.daily "!bash $INSTALL_DIR/daily.sh"
  ok "Git alias created → git daily"
}

###############################################################################
# Function: validate_api_key
# Makes a lightweight API call to check if the key is valid.
###############################################################################
validate_api_key() {
  local key="$1"
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $key" \
    "https://api.openai.com/v1/models")

  [[ "$status" == "200" ]]
}

###############################################################################
# Function: prompt_api_key
# Asks the user for a key and saves it to their shell config.
###############################################################################
prompt_api_key() {
  local reason="$1"
  echo ""
  ask "$reason"

  while true; do
    printf "   Enter your OpenAI API key: "
    read -r api_key </dev/tty

    if [[ -z "$api_key" ]]; then
      ask "A valid API key is required. git daily won't work without one."
      continue
    fi

    info "Validating API key..."
    if validate_api_key "$api_key"; then
      ok "API key is valid"
      save_api_key "$api_key"
      return
    else
      ask "API key is invalid. Please try again."
    fi
  done
}

###############################################################################
# Function: save_api_key
# Appends the key to the user's shell config file.
###############################################################################
save_api_key() {
  local api_key="$1"

  local shell_rc
  shell_rc=$(detect_shell_rc)

  if [[ -n "$shell_rc" ]]; then
    # Remove old git-daily key if present
    sed -i.bak '/# git-daily/d; /OPENAI_API_KEY.*# git-daily/d' "$shell_rc" 2>/dev/null || true
    echo "" >> "$shell_rc"
    echo "# git-daily" >> "$shell_rc"
    echo "export OPENAI_API_KEY=\"$api_key\"" >> "$shell_rc"
    rm -f "${shell_rc}.bak"
    ok "API key saved to $shell_rc"
  else
    warn "Could not detect shell config file. Add this manually:"
    echo "   export OPENAI_API_KEY=\"$api_key\""
  fi
}

###############################################################################
# Function: setup_api_key
###############################################################################
setup_api_key() {
  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    info "Testing existing OPENAI_API_KEY..."
    if validate_api_key "$OPENAI_API_KEY"; then
      ok "OPENAI_API_KEY is valid"
      return
    else
      ask "Existing OPENAI_API_KEY is invalid or expired."
      prompt_api_key "Let's set a new API key."
      return
    fi
  fi

  prompt_api_key "OPENAI_API_KEY is not set in your environment."
}

###############################################################################
# Function: main
###############################################################################
main() {
  echo ""
  echo "  🪖 git-daily installer"
  echo ""
  echo "  ─────────────────────"
  echo ""

  check_dependencies
  install_repo
  setup_alias
  setup_api_key
  echo ""
  echo "  ─────────────────────"
  echo ""
  ok "You're all set!"
  echo ""
  echo "  Now just cd into any repo and run:"
  echo ""
  printf "    \033[1mgit daily\033[0m\n"
  echo ""
  echo "  Works globally — every repo, every branch. 🪖"
  echo ""
  echo "  ─────────────────────"
  echo ""
  local shell_rc
  shell_rc=$(detect_shell_rc)
  local source_cmd="source ${shell_rc:-~/.bashrc}"

  warn "IMPORTANT: Run this to activate the key in your current terminal:"
  echo ""
  echo "   $source_cmd"
  echo ""
  if copy_to_clipboard "$source_cmd"; then
    info "Copied to clipboard — just paste it in your terminal."
  fi
  echo ""
}

main
