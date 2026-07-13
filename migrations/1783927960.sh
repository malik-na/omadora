echo "Rebuild the source-built packages at the versions this Omarchy release expects"

# Walker, Elephant and the cargo TUIs are built from source on Fedora - no package manager can move
# them, so an existing install keeps whatever it was first built with. Omarchy 3.8.2 ships
# Walker/Elephant configs (unlock menu, symbols shortcut, Hyprland 0.55 dispatchers) that the
# 3.5.0-era build does not understand.
#
# omarchy-update-manual-pkgs is the same step omarchy-update runs. Both helpers behind it are
# version-aware, so re-running this when everything is current costs nothing.
omarchy-update-manual-pkgs

omarchy-refresh-walker || true
omarchy-restart-walker || true
