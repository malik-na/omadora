# What changes in Omarchy Quattro

Quattro is **not a normal update — it is a rework of the whole desktop.** If you are coming from
Omarchy 3.8.x, this page is the short, plain list of what is gone, what replaces it, and what is new.
It applies to this Fedora Asahi (Apple Silicon) port.

> TL;DR — the single biggest change: **the bar, launcher, notifications, and on-screen display are no
> longer separate apps. One program (the Quickshell "Omarchy Shell") now does all of it.** And **every
> Hyprland keybinding is now written in Lua, not the old `.conf` format.**

---

## 1. The desktop shell — many apps → one Quickshell shell

| Old (3.8.x) | New (quattro) |
|---|---|
| **waybar** (top bar) | → dropped → **Quickshell** bar |
| **walker** (app launcher) | → dropped → **Quickshell** launcher (`Super + Space`) |
| **elephant** (launcher providers) | → dropped → built into the **Quickshell** shell |
| **mako** (notifications) | → dropped → **Quickshell** notifications |
| **swayosd** (volume/brightness OSD) | → dropped → **Quickshell** OSD |
| **swaybg** (wallpaper) | → dropped → **Quickshell** background service |
| **hyprlock / hypridle** (lock / idle) | → dropped → **Quickshell** lock + idle service |
| **wf-recorder / wl-screenrec / wayfreeze / satty** | → dropped → **gpu-screen-recorder** + shell capture |

The shell also adds things that did not exist before: a clipboard-history overlay, an emoji picker,
reminders, a theme-aware polkit (password) dialog, and a system-tray, all inside the one shell.

**On Fedora this fork installs Quickshell from the official Fedora repository** (`dnf install
quickshell`) — no extra repo needed.

## 2. Hyprland config & keybindings — `.conf` → `.lua`

Hyprland dropped its old `hyprlang` (`.conf`) config in favour of **Lua** (since Hyprland 0.55). So:

- **All keybindings are now Lua.** `bind = SUPER, Q, exec, ...` becomes
  `o.bind("SUPER + Q", "Close window", ...)` in `default/hypr/bindings/*.lua`.
- Old files like `bindings.conf`, `input.conf`, `looknfeel.conf`, `envs.conf`, `autostart.conf` are
  replaced by `bindings/*.lua`, `input.lua`, `looknfeel.lua`, `envs.lua`, `autostart.lua`.
- Theme Hyprland files: `themes/*/hyprland.conf` → `themes/*/hyprland.lua`.

If you had personal bindings in `~/.config/hypr/*.conf`, they need to move to the Lua format.

## 3. Themes — new colour format

- Each theme now has a **`colors.toml`** with semantic colour names (`red`, `accent`, `background`,
  `foreground`, …) and a `mode = "dark"` / `"light"` line.
- The old empty **`light.mode`** marker file is gone — light/dark now comes from `mode` in `colors.toml`.
- `btop.theme` and `swayosd.css` are no longer per-theme files; they are generated from templates.
- New theme tooling: `omarchy-theme-color`, `omarchy-theme-set-templates`, `omarchy-theme-osc`. Theme
  changes are pushed to the running shell live.

## 4. Login & session

- **SDDM** is the login screen, and the session is started through **uwsm** (Universal Wayland Session
  Manager). On this Fedora port SDDM is set up the Fedora way (no Arch-specific launcher wrapper).

## 5. New tools

- First-party tools added upstream: **aether** (wallpaper theming), **omacut** (video trimmer),
  **omawrite** (writing), **tensaku** (screenshot annotation), **cliamp** (music player),
  **tobi-try** (the `try` command), **voxtype** (voice dictation), and **hyprland-preview-share-picker**
  (the screen-share picker). Upstream ships them as Arch packages; none is a Fedora/COPR package, so
  this port installs each from its aarch64 source — an upstream prebuilt binary or a small source build
  — through `install/helpers/fedora-first-party.sh` (version-pinned, and kept current by
  `omarchy-update-manual-pkgs`). See [DEPENDENCIES.md](DEPENDENCIES.md) for the exact source of each.
- **`asdcontrol` is dropped.** Upstream uses it to set the brightness of *external* Apple displays
  (Studio Display / Pro Display XDR) over USB; an Asahi laptop's built-in screen does not need it.

## 6. Paths that moved

- Runtime theme/state moved from `~/.config/omarchy/current/` to **`~/.local/state/omarchy/current/`**.

## 7. What this Fedora fork keeps (and does NOT take from upstream)

Upstream quattro also switches Omarchy to distro **packages** and to Arch-only plumbing. This Fedora
Asahi fork deliberately keeps its own way:

- **Delivery stays git-clone + `dnf`/COPR** — not the pacman package model.
- **`dnf` / COPR**, never pacman / AUR / `yay`. The Hyprland stack (including `uwsm` and
  `gpu-screen-recorder`) comes from the single `lionheartp/Hyprland` COPR; the old
  `solopasha/hyprland` and `erikreider/swayosd` COPRs are dropped (unmaintained / retired stack).
  See [DEPENDENCIES.md](DEPENDENCIES.md) for every source.
- **`iwd`** stays as the Wi-Fi backend for NetworkManager (a deliberate fork choice).
- **`firewalld`**, not UFW.
- **aarch64 / Apple Silicon only** — Intel, NVIDIA, Framework, ASUS, Surface, Dell, and Apple T2
  (Intel-Mac) hardware paths are skipped.
- Boot stays **dracut** (Fedora Asahi), not `mkinitcpio` / `limine`.

## Where did my app go?

- No bar/launcher/notifications after upgrade? The Quickshell shell starts from Hyprland autostart —
  log out and back in (or reboot) once after upgrading.
- A binding stopped working? Check whether it is in the new `default/hypr/bindings/*.lua` and move any
  personal `.conf` binding to Lua.
