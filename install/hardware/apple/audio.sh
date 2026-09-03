#!/bin/bash
# Sound on Apple Silicon needs three things this install would otherwise never
# get, for three different reasons.
#
# PipeWire's PulseAudio server: on Arch the package is pipewire-pulse; on Fedora
# Asahi it is pipewire-pulseaudio (already in omarchy-base.packages.fedora).
# Wireplumber can pull in pipewire without the Pulse server, leaving pactl with
# "Connection refused" and every volume/mute key dead while brightness still
# works. Name the Fedora package here so omarchy-pkg-* checks match rpm -q.
#
# Realtime scheduling: rtkit is only an optional dependency of pipewire, so
# nothing here would pull it in. Without it pipewire's data threads run at
# normal priority, and any load spike delays the DSP cycle long enough to
# underrun -- heard as crackling or popping that gets worse under load. The
# Asahi speaker filter chain runs several convolvers per cycle, so it is more
# exposed to this than a plain sink.
#
# Then the Apple parts: asahi-audio carries the UCM profiles and the DSP filter
# chain that makes a speaker sink exist at all, and speakersafetyd is what
# allows the speakers to play. Without the daemon the kernel keeps them muted,
# on purpose -- these drivers can be damaged by what the hardware will happily
# ask them to do.

compatible="${OMARCHY_APPLE_COMPATIBLE:-/proc/device-tree/compatible}"
OMARCHY_ASAHI_AUDIO_PACKAGES_CHANGED=0

# Every device-tree machine has a compatible file, so it has to name Apple --
# otherwise a Raspberry Pi would install the Asahi stack too.
[[ $(uname -m) == "aarch64" ]] || return 0
[[ -f $compatible ]] && grep -Faiq 'apple,' "$compatible" || return 0

# pkg-missing rather than a bare pkg-add, so the migration can tell whether this
# actually installed anything and only then ask for a reboot.
# Fedora package name is pipewire-pulseaudio (not Arch's pipewire-pulse).
if omarchy-pkg-missing rtkit pipewire-pulseaudio pipewire-alsa asahi-audio speakersafetyd; then
  echo "Installing the Apple Silicon audio stack"
  omarchy-pkg-add rtkit pipewire-pulseaudio pipewire-alsa asahi-audio speakersafetyd ||
    echo "Warning: some audio packages could not be installed; sound may not work."

  # A warning rather than a failure: hardware setup runs under set -e, so failing
  # here would abort the whole install over speakers that can be fixed later.
  if omarchy-pkg-present rtkit pipewire-pulseaudio pipewire-alsa asahi-audio speakersafetyd; then
    OMARCHY_ASAHI_AUDIO_PACKAGES_CHANGED=1
  else
    echo "Warning: the protected Asahi audio stack is incomplete; the speakers stay muted." >&2
  fi
fi

# The daemon has to be running before the speakers will produce anything.
sudo systemctl enable --now speakersafetyd >/dev/null 2>&1 ||
  echo "Warning: speakersafetyd did not start; the speakers stay muted."

# pipewire-pulseaudio is socket-activated per user, so enabling it system-wide is
# not the job; the user units are enabled at first run.
