#!/bin/bash
# Seed the fonts that aren't packaged: the Omarchy glyph font used by the shell,
# plus an icon-capable fallback on Fedora. Runs as the user.
OMARCHY_INSTALL="${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}"
OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
source "$OMARCHY_INSTALL/helpers/distro.sh"

# Omarchy glyph font (quattro ships it under default/fonts/omarchy/).
mkdir -p ~/.local/share/fonts
cp "$OMARCHY_PATH/default/fonts/omarchy/omarchy.ttf" ~/.local/share/fonts/

# Ensure an icon-capable font fallback exists on Fedora so shell module glyphs
# render at a consistent size.
if is_fedora && ! rpm -q cascadia-mono-nf-fonts &>/dev/null; then
  sudo dnf install -y cascadia-mono-nf-fonts || true
fi

fc-cache
