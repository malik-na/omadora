echo "Enable Omarchy Plymouth theme and quiet splash on the kernel cmdline"

# Fresh installs run install/login/plymouth.sh then dracut.sh. Existing machines
# still boot with verbose logs because quiet/splash were never applied.
leaf="$OMARCHY_PATH/install/login/plymouth.sh"
[[ -f $leaf ]] || exit 0

# shellcheck disable=SC1090
source "$leaf"

# Bundle the theme into every initramfs now that the theme and cmdline are set.
if omarchy-cmd-present omarchy-refresh-plymouth; then
  omarchy-refresh-plymouth || true
elif [[ -f $OMARCHY_PATH/install/login/dracut.sh ]]; then
  # shellcheck disable=SC1090
  source "$OMARCHY_PATH/install/login/dracut.sh" || true
fi
