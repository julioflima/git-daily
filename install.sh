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
warn()  { printf "\033[1;33m⚠\033[0m %s\n" "$1"; }
error() { printf "\033[1;31m✖\033[0m %s\n" "$1" >&2; exit 1; }

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
    warn "Git alias 'daily' already exists: $current"
    printf "   Overwrite? [y/N] "
    read -r answer </dev/tty
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
      info "Skipped alias setup"
      return
    fi
  fi

  git config --global alias.daily "!bash $INSTALL_DIR/daily.sh"
  ok "Git alias created → git daily"
}

###############################################################################
# Function: setup_api_key
###############################################################################
setup_api_key() {
  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    ok "OPENAI_API_KEY already set"
    return
  fi

  echo ""
  warn "OPENAI_API_KEY is not set in your environment."
  printf "   Enter your OpenAI API key (or press Enter to skip): "
  read -r api_key </dev/tty

  if [[ -z "$api_key" ]]; then
    warn "Skipped API key setup. You'll need to set it later:"
    echo "   export OPENAI_API_KEY=\"sk-...\""
    return
  fi

  # Detect shell config file
  local shell_rc=""
  if [[ -f "$HOME/.zshrc" ]]; then
    shell_rc="$HOME/.zshrc"
  elif [[ -f "$HOME/.bashrc" ]]; then
    shell_rc="$HOME/.bashrc"
  elif [[ -f "$HOME/.bash_profile" ]]; then
    shell_rc="$HOME/.bash_profile"
  fi

  if [[ -n "$shell_rc" ]]; then
    echo "" >> "$shell_rc"
    echo "# git-daily" >> "$shell_rc"
    echo "export OPENAI_API_KEY=\"$api_key\"" >> "$shell_rc"
    ok "API key added to $shell_rc"
    info "Run 'source $shell_rc' or open a new terminal to activate it"
  else
    warn "Could not detect shell config file. Add this manually:"
    echo "   export OPENAI_API_KEY=\"$api_key\""
  fi
}

###############################################################################
# Function: main
###############################################################################
main() {
  echo ""
  echo "  🪖 git-daily installer"
  echo "  ─────────────────────"
  echo ""

  check_dependencies
  install_repo
  setup_alias
  setup_api_key

  echo ""
  echo "  ─────────────────────"
  ok "Done! Run 'git daily' inside any repo."
  echo ""
}

main
