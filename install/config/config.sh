#!/bin/bash
# Seed the shipped user configs. On Arch these come from a package-populated
# /etc/skel; the git-clone fork has no package, so copy them out of the clone.
# Runs as the user.
OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"

# Shipped ~/.config tree.
mkdir -p ~/.config
cp -R "$OMARCHY_PATH"/config/* ~/.config/

# Shipped bashrc (it sources the rest of the shell setup from $OMARCHY_PATH).
cp "$OMARCHY_PATH/default/bashrc" ~/.bashrc

# Make Omarchy commands available in login sessions (e.g. the SDDM Wayland
# session), not just interactive bash.
if ! grep -q 'OMARCHY_PATH=' ~/.profile 2>/dev/null; then
  cat >>~/.profile <<EOF

export OMARCHY_PATH="$OMARCHY_PATH"
export PATH="\$OMARCHY_PATH/bin:\$PATH"
EOF
fi

# User-local pip/npm tools on PATH as well.
if ! grep -q 'PATH="$HOME/.local/bin:$PATH"' ~/.profile 2>/dev/null; then
  cat >>~/.profile <<'EOF'
export PATH="$HOME/.local/bin:$PATH"
EOF
fi

# Ensure bash login shells (used by the SDDM session wrapper) load ~/.profile.
if ! grep -q 'if \[ -f ~/.profile \]; then' ~/.bash_profile 2>/dev/null; then
  cat >>~/.bash_profile <<'EOF'

if [ -f ~/.profile ]; then
    . ~/.profile
fi
EOF
fi
