echo "Add cliamp music TUI player (Super+Shift+Alt+M)"

# cliamp is not in Fedora and not in any COPR we enable, so it cannot go through omarchy-pkg-add
# (rpm would never see it). It is installed from the project's own release installer, pinned to a
# tag rather than HEAD so an omarchy-update cannot pull in a moving target. This is the same
# pipe-to-shell pattern Omarchy already ships for the astral.sh uv installer.
# A failure here is not fatal: cliamp is an optional music TUI, not part of the desktop.
CLIAMP_VERSION="v1.57.1"
CLIAMP_INSTALLER="https://raw.githubusercontent.com/bjarneo/cliamp/$CLIAMP_VERSION/install.sh"

if ! command -v cliamp >/dev/null 2>&1; then
  if curl -fsSL "$CLIAMP_INSTALLER" | sh; then
    echo "[INFO] Installed cliamp $CLIAMP_VERSION"
  else
    echo "[WARNING] cliamp install failed - skipping its keybinding."
    echo "[WARNING] Install it later from https://github.com/bjarneo/cliamp"
  fi
fi

if command -v cliamp >/dev/null 2>&1 &&
  [[ -f ~/.config/hypr/bindings.conf ]] && ! grep -q "cliamp" ~/.config/hypr/bindings.conf; then
  sed -i '/^bindd = SUPER SHIFT, M, Music, exec, omarchy-launch-or-focus spotify/a bindd = SUPER SHIFT ALT, M, Music TUI, exec, omarchy-launch-or-focus-tui cliamp' ~/.config/hypr/bindings.conf
fi
