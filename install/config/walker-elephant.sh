#!/bin/bash

# Configure Walker + Elephant integration and refresh runtime files.
mkdir -p ~/.config/elephant/menus
ln -snf "$OMARCHY_PATH/default/elephant/omarchy_themes.lua" ~/.config/elephant/menus/omarchy_themes.lua
ln -snf "$OMARCHY_PATH/default/elephant/omarchy_background_selector.lua" ~/.config/elephant/menus/omarchy_background_selector.lua
ln -snf "$OMARCHY_PATH/default/elephant/omarchy_unlocks.lua" ~/.config/elephant/menus/omarchy_unlocks.lua

mkdir -p ~/.config/systemd/user/elephant.service.d
cat >~/.config/systemd/user/elephant.service.d/10-omarchy-path.conf <<EOF
[Service]
Environment=OMARCHY_PATH=$OMARCHY_PATH
EOF

mkdir -p ~/.config/qalculate
touch ~/.config/qalculate/qalc.cfg

if command -v omarchy-refresh-walker >/dev/null 2>&1; then
  omarchy-refresh-walker || true
fi

if [ -x "$HOME/.local/bin/elephant" ] || command -v elephant >/dev/null 2>&1; then
  elephant service enable || true

  cat >~/.config/systemd/user/elephant.service.d/20-exec.conf <<EOF
[Service]
ExecStart=
ExecStart=%h/.local/bin/elephant
EOF

  cat >~/.config/systemd/user/elephant.service.d/30-path.conf <<EOF
[Service]
Environment=PATH=$OMARCHY_PATH/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin
EOF

  systemctl --user daemon-reload || true
  systemctl --user restart elephant.service || true
fi
