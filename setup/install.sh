#!/usr/bin/env bash

# Installing everything you need for your WyrmTech Mac / Linux setup

set -euo pipefail

echo "Starting installations..."

# Install Xcode Command Line Tools on macOS (required for Homebrew and most dev tools)
if [[ "$OSTYPE" == "darwin"* ]]; then
  if ! xcode-select -p &> /dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    # Wait for installation to complete before proceeding
    until xcode-select -p &> /dev/null; do
      sleep 5
    done
    echo "✓ Xcode Command Line Tools installed"
  else
    echo "✓ Xcode Command Line Tools already installed"
  fi
fi

setup_brew_env() {
  # Support Homebrew locations across Apple Silicon, Intel macOS, and Linuxbrew.
  local brew_bin=""
  local shell_name=""

  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    brew_bin="/opt/homebrew/bin/brew"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    brew_bin="/usr/local/bin/brew"
  elif [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    brew_bin="/home/linuxbrew/.linuxbrew/bin/brew"
  elif command -v brew &> /dev/null; then
    brew_bin="$(command -v brew)"
  fi

  if [[ -n "$brew_bin" ]]; then
    shell_name="$(basename "${SHELL:-}")"

    if [[ "$shell_name" == "zsh" || "$shell_name" == "bash" ]]; then
      eval "$("$brew_bin" shellenv "$shell_name")"
    else
      eval "$("$brew_bin" shellenv)"
    fi
  fi
}

persist_brew_env_for_user_shell() {
  local brew_prefix=""
  local shell_name=""
  local shellenv_line=""

  if ! command -v brew &> /dev/null; then
    return
  fi

  brew_prefix="$(brew --prefix 2>/dev/null || true)"
  if [[ -z "$brew_prefix" ]]; then
    return
  fi

  shell_name="$(basename "${SHELL:-}")"

  if [[ "$shell_name" == "zsh" || "$shell_name" == "bash" ]]; then
    shellenv_line="eval \"\$(${brew_prefix}/bin/brew shellenv ${shell_name})\""
  else
    shellenv_line="eval \"\$(${brew_prefix}/bin/brew shellenv)\""
  fi

  add_line_if_missing() {
    local target_file="$1"

    if [[ ! -f "$target_file" ]]; then
      touch "$target_file"
    fi

    if ! grep -Fq "$shellenv_line" "$target_file"; then
      {
        echo ""
        echo "# Added by WyrmTech setup"
        echo "$shellenv_line"
      } >> "$target_file"
      echo "Added Homebrew PATH setup to $target_file"
    fi
  }

  if [[ "$shell_name" == "zsh" ]]; then
    add_line_if_missing "$HOME/.zprofile"
    add_line_if_missing "$HOME/.zshrc"
  elif [[ "$shell_name" == "bash" ]]; then
    add_line_if_missing "$HOME/.bash_profile"
    add_line_if_missing "$HOME/.bashrc"
  else
    add_line_if_missing "$HOME/.profile"
  fi
}

if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew..."
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash

  # Add Homebrew to PATH for the current session.
  setup_brew_env
  
else
  echo "✓ Homebrew already installed"
  setup_brew_env
fi

persist_brew_env_for_user_shell

persist_goenv_init_for_user_shell() {
  local shell_name=""
  local target_file=""
  local goenv_init_line='eval "$(goenv init -)"'

  if ! command -v goenv &> /dev/null; then
    return
  fi

  shell_name="$(basename "${SHELL:-}")"

  if [[ "$shell_name" == "zsh" ]]; then
    target_file="$HOME/.zshrc"
  elif [[ "$shell_name" == "bash" ]]; then
    # Prefer bash_profile over bashrc to avoid initialization loops on some systems.
    target_file="$HOME/.bash_profile"
  else
    target_file="$HOME/.profile"
  fi

  if [[ ! -f "$target_file" ]]; then
    touch "$target_file"
  fi

  if ! grep -Fq "$goenv_init_line" "$target_file"; then
    {
      echo ""
      echo "# Added by WyrmTech setup"
      echo "$goenv_init_line"
    } >> "$target_file"
    echo "Added goenv init to $target_file"
  fi
}

sync_codex_rules() {
  local source_url="https://raw.githubusercontent.com/wyrm-tech/.github/refs/heads/main/.codex/rules/default.rules"
  local source_rules_tmp=""
  local target_rules_dir="$HOME/.codex/rules"
  local target_rules="$target_rules_dir/default.rules"
  local added_count=0

  source_rules_tmp="$(mktemp "${TMPDIR:-/tmp}/wyrmtech-codex-rules.XXXXXX")"

  if ! curl -fsSL "$source_url" -o "$source_rules_tmp"; then
    echo "⚠ Failed to download Codex rules from $source_url - skipping Codex rules sync"
    rm -f "$source_rules_tmp"
    return
  fi

  mkdir -p "$target_rules_dir"
  touch "$target_rules"

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" ]]; then
      continue
    fi

    if ! grep -Fqx "$line" "$target_rules"; then
      echo "$line" >> "$target_rules"
      added_count=$((added_count + 1))
    fi
  done < "$source_rules_tmp"

  rm -f "$source_rules_tmp"

  if [[ $added_count -gt 0 ]]; then
    echo "✓ Added $added_count Codex rule(s) to $target_rules"
  else
    echo "✓ Codex rules already up to date"
  fi
}

persist_qbo_env_for_user_shell() {
  local qbo_redirect_uri_line='export QBO_REDIRECT_URI=https://developer.intuit.com/v2/OAuth2Playground/RedirectUrl'
  local go_bin_path_line='export PATH="$HOME/go/bin:$PATH"'
  local qbo_redirect_uri_already_set="${QBO_REDIRECT_URI:-}"
  local shell_name=""

  shell_name="$(basename "${SHELL:-}")"

  add_qbo_line_if_missing() {
    local target_file="$1"
    local line="$2"

    if [[ ! -f "$target_file" ]]; then
      touch "$target_file"
    fi

    if ! grep -Fq "$line" "$target_file"; then
      {
        echo ""
        echo "# Added by WyrmTech setup"
        echo "$line"
      } >> "$target_file"
      echo "Added to $target_file: $line"
    fi
  }

  if [[ "$shell_name" == "zsh" ]]; then
    add_qbo_line_if_missing "$HOME/.zprofile" "$go_bin_path_line"
    if [[ -z "$qbo_redirect_uri_already_set" ]]; then
      add_qbo_line_if_missing "$HOME/.zprofile" "$qbo_redirect_uri_line"
    fi
    add_qbo_line_if_missing "$HOME/.zshrc" "$go_bin_path_line"
    if [[ -z "$qbo_redirect_uri_already_set" ]]; then
      add_qbo_line_if_missing "$HOME/.zshrc" "$qbo_redirect_uri_line"
    fi
  elif [[ "$shell_name" == "bash" ]]; then
    add_qbo_line_if_missing "$HOME/.bash_profile" "$go_bin_path_line"
    if [[ -z "$qbo_redirect_uri_already_set" ]]; then
      add_qbo_line_if_missing "$HOME/.bash_profile" "$qbo_redirect_uri_line"
    fi
    add_qbo_line_if_missing "$HOME/.bashrc" "$go_bin_path_line"
    if [[ -z "$qbo_redirect_uri_already_set" ]]; then
      add_qbo_line_if_missing "$HOME/.bashrc" "$qbo_redirect_uri_line"
    fi
  else
    add_qbo_line_if_missing "$HOME/.profile" "$go_bin_path_line"
    if [[ -z "$qbo_redirect_uri_already_set" ]]; then
      add_qbo_line_if_missing "$HOME/.profile" "$qbo_redirect_uri_line"
    fi
  fi

  export PATH="$HOME/go/bin:$PATH"
  if [[ -z "$qbo_redirect_uri_already_set" ]]; then
    export QBO_REDIRECT_URI="https://developer.intuit.com/v2/OAuth2Playground/RedirectUrl"
    echo "✓ QBO_REDIRECT_URI set for current session"
  else
    echo "✓ QBO_REDIRECT_URI already set - leaving existing value unchanged"
  fi
  echo "✓ QBO environment configured for current session"
}

install_latest_go_with_goenv() {
  local latest_go_version=""

  if ! command -v goenv &> /dev/null; then
    echo "⚠ goenv not found - skipping Go installation"
    return
  fi

  latest_go_version="$(goenv install -l | sed 's/^[[:space:]]*//' | grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$' | sort -V | tail -n 1)"

  if [[ -z "$latest_go_version" ]]; then
    echo "⚠ Could not determine latest Go version from goenv"
    return
  fi

  if goenv versions --bare | grep -Fxq "$latest_go_version"; then
    echo "✓ Go ${latest_go_version} already installed via goenv"
  else
    echo "Installing Go ${latest_go_version} via goenv..."
    goenv install "$latest_go_version"
  fi

  goenv global "$latest_go_version"
  goenv rehash
  echo "✓ Set global Go version to ${latest_go_version}"
}

install_ramp_cli() {
  if command -v ramp &> /dev/null; then
    echo "✓ Ramp CLI already installed"
    return
  fi

  echo "Installing Ramp CLI..."
  if curl -fsSL https://agents.ramp.com/install.sh | sh; then
    echo "✓ Ramp CLI installed"
  else
    echo "⚠ Failed to install Ramp CLI"
  fi
}

brew_bundle_check_with_fallback() {
  local brewfile="$1"

  if brew bundle check --file="$brewfile" >/dev/null 2>&1; then
    return 0
  fi

  if HOMEBREW_NO_INSTALL_FROM_API=1 brew bundle check --file="$brewfile" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

brew_bundle_install_with_fallback() {
  local brewfile="$1"

  if brew bundle --file="$brewfile"; then
    return 0
  fi

  echo "Retrying brew bundle with HOMEBREW_NO_INSTALL_FROM_API=1 due to Homebrew API/cask issues..."
  HOMEBREW_NO_INSTALL_FROM_API=1 brew bundle --file="$brewfile"
}

# Install all Homebrew packages from Brewfile
brewfile_tmp="$(mktemp "${TMPDIR:-/tmp}/wyrmtech-brewfile.XXXXXX")"
go_brewfile_tmp="$(mktemp "${TMPDIR:-/tmp}/wyrmtech-go-brewfile.XXXXXX")"
trap 'rm -f "$brewfile_tmp" "$go_brewfile_tmp"' EXIT

curl -fsSL https://raw.githubusercontent.com/wyrm-tech/.github/refs/heads/main/setup/Brewfile -o "$brewfile_tmp"

if brew_bundle_check_with_fallback "$brewfile_tmp"; then
  echo "✓ Homebrew packages already installed"
else
  echo "Installing Homebrew packages from Brewfile..."
  brew_bundle_install_with_fallback "$brewfile_tmp"
fi

if command -v qbo &> /dev/null; then
  persist_qbo_env_for_user_shell
else
  echo "⚠ qbo not found after Homebrew installation - skipping QBO environment setup"
fi

persist_qbo_credentials_for_user_shell() {
  local qbo_client_id_line='export QBO_CLIENT_ID='
  local qbo_client_secret_line='export QBO_CLIENT_SECRET='
  local shell_name=""

  shell_name="$(basename "${SHELL:-}")"

  if ! command -v gh &> /dev/null; then
    echo "⚠ GitHub CLI not found — skipping QBO credentials fetch"
    return
  fi

  echo "Fetching QBO credentials from GitHub repository..."
  
  local qbo_client_id=""
  local qbo_client_secret=""

  qbo_client_id=$(gh variable get QBO_CLIENT_ID --env qbo --repo wyrm-tech/fluffy-financials 2>/dev/null || true)
  qbo_client_secret=$(gh variable get QBO_CLIENT_SECRET --env qbo --repo wyrm-tech/fluffy-financials 2>/dev/null || true)

  # Fallback to repository-level variables if environment-scoped variables are not found.
  if [[ -z "$qbo_client_id" ]]; then
    qbo_client_id=$(gh variable get QBO_CLIENT_ID --repo wyrm-tech/fluffy-financials 2>/dev/null || true)
  fi
  if [[ -z "$qbo_client_secret" ]]; then
    qbo_client_secret=$(gh variable get QBO_CLIENT_SECRET --repo wyrm-tech/fluffy-financials 2>/dev/null || true)
  fi

  if [[ -z "$qbo_client_id" || -z "$qbo_client_secret" ]]; then
    echo "⚠ Could not fetch QBO credentials from GitHub repository"
    echo "ℹ This is expected if you are not on the finance team"
    return
  fi

  add_qbo_cred_line_if_missing() {
    local target_file="$1"
    local var_name="$2"
    local var_value="$3"
    local var_line="export ${var_name}=${var_value}"
    local existing_value="${!var_name:-}"

    if [[ -n "$existing_value" ]]; then
      return
    fi

    if [[ ! -f "$target_file" ]]; then
      touch "$target_file"
    fi

    if ! grep -Fq "export $var_name" "$target_file"; then
      {
        echo ""
        echo "# Added by WyrmTech setup"
        echo "$var_line"
      } >> "$target_file"
      echo "Added to $target_file: export $var_name"
    fi
  }

  if [[ "$shell_name" == "zsh" ]]; then
    add_qbo_cred_line_if_missing "$HOME/.zprofile" "QBO_CLIENT_ID" "$qbo_client_id"
    add_qbo_cred_line_if_missing "$HOME/.zprofile" "QBO_CLIENT_SECRET" "$qbo_client_secret"
    add_qbo_cred_line_if_missing "$HOME/.zshrc" "QBO_CLIENT_ID" "$qbo_client_id"
    add_qbo_cred_line_if_missing "$HOME/.zshrc" "QBO_CLIENT_SECRET" "$qbo_client_secret"
  elif [[ "$shell_name" == "bash" ]]; then
    add_qbo_cred_line_if_missing "$HOME/.bash_profile" "QBO_CLIENT_ID" "$qbo_client_id"
    add_qbo_cred_line_if_missing "$HOME/.bash_profile" "QBO_CLIENT_SECRET" "$qbo_client_secret"
    add_qbo_cred_line_if_missing "$HOME/.bashrc" "QBO_CLIENT_ID" "$qbo_client_id"
    add_qbo_cred_line_if_missing "$HOME/.bashrc" "QBO_CLIENT_SECRET" "$qbo_client_secret"
  else
    add_qbo_cred_line_if_missing "$HOME/.profile" "QBO_CLIENT_ID" "$qbo_client_id"
    add_qbo_cred_line_if_missing "$HOME/.profile" "QBO_CLIENT_SECRET" "$qbo_client_secret"
  fi

  if [[ -z "${QBO_CLIENT_ID:-}" ]]; then
    export QBO_CLIENT_ID="$qbo_client_id"
    echo "✓ QBO_CLIENT_ID set for current session"
  else
    echo "✓ QBO_CLIENT_ID already set - leaving existing value unchanged"
  fi

  if [[ -z "${QBO_CLIENT_SECRET:-}" ]]; then
    export QBO_CLIENT_SECRET="$qbo_client_secret"
    echo "✓ QBO_CLIENT_SECRET set for current session"
  else
    echo "✓ QBO_CLIENT_SECRET already set - leaving existing value unchanged"
  fi
  echo "✓ QBO credentials set for current session"
}

persist_qbo_credentials_for_user_shell

persist_goenv_init_for_user_shell
install_latest_go_with_goenv
sync_codex_rules
install_ramp_cli

# Install Go-based tools only after goenv has installed and configured Go.
curl -fsSL https://raw.githubusercontent.com/wyrm-tech/.github/refs/heads/main/setup/Brewfile.goinstalls -o "$go_brewfile_tmp"

if brew_bundle_check_with_fallback "$go_brewfile_tmp"; then
  echo "✓ Go Brewfile tools already installed"
else
  echo "Installing Go tools from Brewfile.goinstalls..."
  brew_bundle_install_with_fallback "$go_brewfile_tmp"
fi

echo "✓ Installation complete"
