#!/usr/bin/env bash

# Installing everything you need for your WyrmTech Mac / Linux setup

set -euo pipefail

echo "Starting installations..."

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

# Install all Homebrew packages from Brewfile
brewfile_tmp="$(mktemp "${TMPDIR:-/tmp}/wyrmtech-brewfile.XXXXXX")"
trap 'rm -f "$brewfile_tmp"' EXIT

curl -fsSL https://raw.githubusercontent.com/wyrmtech/.github/main/setup/Brewfile -o "$brewfile_tmp"

if brew bundle check --file="$brewfile_tmp" >/dev/null 2>&1; then
  echo "✓ Homebrew packages already installed"
else
  echo "Installing Homebrew packages from Brewfile..."
  brew bundle --file="$brewfile_tmp"
fi

echo "✓ Installation complete"
