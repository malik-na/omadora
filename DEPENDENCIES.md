# Where Omarchy Mac Fedora gets its software

Every external source this repository pulls from, in one place. If something here disappears, breaks,
or changes hands, the installer or an update breaks - so this is the list to check first when either
one fails, and the list to review when you care about what runs on your machine.

Scope: Fedora Asahi Remix 44+, aarch64, on the quattro line. Everything below is fetched at install
time or during `omarchy-update`; nothing is vendored into this repository.

---

## 1. Fedora's own repositories

The default source for almost everything. Nothing special is configured.

| Repository | Used for |
|---|---|
| `fedora`, `updates` (Fedora 44, aarch64) | the bulk of the package set - **Quickshell** (the whole bar/launcher/OSD shell, an official Fedora package), Chromium, foot, Alacritty, SDDM, PipeWire, fonts, snapper, Docker, Java, and so on. See `install/omarchy-base.packages.fedora` and `install/omarchy-other.packages.fedora`. |

**Fedora 44 is required.** Several packages the older lists used no longer exist on 43, and the
Hyprland build Omarchy targets is only published for the 44 chroot. Every entry point stops on an
older release and prints the upgrade instructions.

## 2. COPR repositories

COPR is Fedora's user-contributed build service. These are third-party builds - they are not reviewed
by Fedora, and each one is a person who can stop maintaining it.

### Required - the install fails without them

| COPR | What it provides | Why we need it |
|---|---|---|
| [`lionheartp/Hyprland`](https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/) | `hyprland` (0.55.x), `hyprsunset`, `hyprpicker`, `hyprland-qt-support`, `hyprland-guiutils`, `xdg-desktop-portal-hyprland`, `uwsm`, `gpu-screen-recorder` | Fedora does not ship Hyprland for aarch64. This is the build that works on Apple Silicon, and the only one with a Fedora 44 chroot. It is pinned to `priority=10` (with core GTK/Pango/Cairo excluded) so dnf prefers it for exactly these packages. |
| [`atim/starship`](https://copr.fedorainfracloud.org/coprs/atim/starship/) | `starship` | prompt |
| [`atim/lazygit`](https://copr.fedorainfracloud.org/coprs/atim/lazygit/) | `lazygit` | git TUI |

### Optional - a failure here is not fatal

| COPR | What it provides | Notes |
|---|---|---|
| [`nclundell/fedora-extras`](https://copr.fedorainfracloud.org/coprs/nclundell/fedora-extras/) | `lazydocker`, `bottom`, `nushell`, `yazi`, and others | assorted TUIs |
| [`scottames/ghostty`](https://copr.fedorainfracloud.org/coprs/scottames/ghostty/) | `ghostty` | only needed by `omarchy-install-terminal ghostty`. The default terminal is alacritty, so this must never be required - it used to be, pointing at a COPR that did not exist, and that alone killed every install. |

Two COPRs the 3.8.x line used are gone on purpose: `solopasha/hyprland` (unmaintained - no builds
since 2025-10 - and its only contribution, satty, is retired by quattro) and `erikreider/swayosd`
(swayosd is retired by quattro; the shell draws the OSD). `install/helpers/fedora-copr-protect.sh`
lists both as dead repos so upgrades remove them from existing installs.

## 3. Built from source at install time

The 3.8.x line compiled walker, elephant, impala and wiremix here; quattro retires all of them in
favour of the Quickshell shell, so the only source build left is:

| Software | Source | Version | Notes |
|---|---|---|---|
| `grub-btrfs` | <https://github.com/Antynea/grub-btrfs> | default branch | snapshot boot entries |

quattro's first-party tools (`aether`, `cliamp`, `omacut`, `omawrite`, `tensaku`, `tobi-try`,
`voxtype`, `asdcontrol`) ship as Arch packages upstream and have **no Fedora build yet** - they are
not installed by this port until they are packaged or a build step lands.

## 4. Binaries and installers fetched over the network

These run code that is not in any package manager. They are listed here precisely because they
deserve a second look.

| What | Source | How |
|---|---|---|
| `mise` (runtime manager) | <https://mise.jdx.dev/install.sh> | **piped to a shell** |
| `uv` (Python tooling) | <https://astral.sh/uv/install.sh> | **piped to a shell**, upstream Omarchy's own step |
| JetBrainsMono Nerd Font | <https://github.com/ryanoasis/nerd-fonts> latest release | tarball into `~/.local/share/fonts`; the shell, foot and the SDDM theme render with it and Fedora only packages the unpatched font |
| `lazydocker` | `nclundell/fedora-extras` COPR (package), GitHub release only as fallback | it used to come from GitHub as a loose binary in `/usr/local/bin`, which nothing ever updated |
| `gum` (installer UI) | Fedora, with a GitHub release as fallback | dnf first. The old code went to GitHub first, with a pinned asset that no longer exists - every install started with a 404 and ran with no UI. |
| 1Password | <https://downloads.1password.com/linux/tar/stable/aarch64/> | only via `omarchy-install-1password` |
| LazyVim starter config | <https://github.com/LazyVim/starter> | `omarchy-lazyvim-setup` |
| Web app icons | `cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons` | PNGs for the installed web apps |

## 5. Flatpak

| Remote | Apps |
|---|---|
| [Flathub](https://flathub.org) | Typora (`io.typora.Typora`), LocalSend (`org.localsend.localsend_app`), Obsidian (`md.obsidian.Obsidian`), Moonlight (`com.moonlight_stream.Moonlight`) |

All are installed `--user`, and `omarchy-remove-preinstalls` removes them the same way.

## 6. Language runtimes and their package registries

| Manager | What comes from it |
|---|---|
| `mise` | node, bun, deno, zls (runtimes; **bun is not a Fedora package and never will be - it comes from mise**) |
| npm registry, via `omarchy-npx-install` wrappers | `@openai/codex`, `@google/gemini-cli`, `@github/copilot`, `@earendil-works/pi-coding-agent`, `@kitlangton/ghui`, `playwright` |
| pip (`--user`) | `terminaltexteffects` (install animations) |

## 7. How each source gets updated

`omarchy-update` runs `dnf upgrade`, then the migrations, then `omarchy-update-manual-pkgs`, which
covers what dnf cannot reach:

| Source | Updated by |
|---|---|
| Fedora repos and every COPR | `dnf upgrade` |
| Flatpak apps (Typora, LocalSend, Obsidian, Moonlight) | `flatpak update --user`, in `omarchy-update-manual-pkgs`. Upstream gets these from the AUR, so `yay -Sua` swept them up; on Fedora nothing was updating them at all until this step existed. |
| npx-wrapped npm tools (codex, gemini, copilot, pi, ghui, playwright) | each run resolves the package fresh (`npx --prefer-online`), so they self-update |
| mise runtimes (node, bun, deno, zls) | **not updated automatically.** `mise use -g <tool>@latest` re-resolves when run by hand. |
| `uv`, `terminaltexteffects` (pip), 1Password, LazyVim starter, JetBrainsMono Nerd Font | **not updated automatically** - they are installed once |

## 8. What this repository does *not* use

No AUR, no `pacman`/`yay`/`paru`, no `mkinitcpio`, no `limine` - those are upstream Omarchy's, and
every path here goes through `dnf`, `rpm` and COPR instead. Boot and initramfs are `dracut` and
`grub-btrfs`. The terminal is `alacritty`, not ghostty. No waybar, walker, elephant, mako or swayosd
either - quattro retired them, and the one Quickshell shell does all of it. x86-only hardware support
(NVIDIA, Intel, Dell, ASUS, Lenovo, Framework) is present but never wired in: it is guarded by
`omarchy-hw-*` checks that cannot match on Apple Silicon.
