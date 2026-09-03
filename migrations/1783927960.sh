echo "Rebuild the source-built packages at the versions this Omarchy release expects"

# Obsolete since quattro: walker, elephant and the cargo TUIs (impala, wiremix) are retired, so
# there is nothing left to rebuild from source. Flatpak apps are still refreshed by every
# omarchy-update via omarchy-update-manual-pkgs, which is all this migration still needs to do.
omarchy-update-manual-pkgs
