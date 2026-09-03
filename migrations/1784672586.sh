echo "Switch to the Omarchy quickshell-git build so shell restarts wait for instance exit"

if ! omarchy-pkg-present quickshell-git; then
  # pacman only resolves packages from sync repos, and quickshell-git is served
  # by the [omarchy-aarch64] repo. If this machine cannot see it there -- a 3.x
  # pacman.conf predating the repo section, or the binary not published yet --
  # skip instead of failing: a failed migration aborts omarchy-migrate's whole
  # run and retries at every login. Plain quickshell keeps the desktop working;
  # only synchronous shell restarts wait-for-exit is lost until it appears.
  if ! pacman -Si quickshell-git &>/dev/null; then
    echo "quickshell-git is not in any configured repo; keeping plain quickshell" >&2
    exit 0
  fi

  # One transaction with --ask 4 so pacman accepts replacing the conflicting
  # quickshell package in place; packages depending on quickshell stay
  # satisfied through the provides.
  sudo pacman -S --noconfirm --ask 4 quickshell-git
fi
