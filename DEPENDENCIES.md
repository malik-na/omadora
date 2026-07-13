# Where Omarchy Mac Fedora gets its software

Every external source this repository pulls from, in one place. If something here disappears, breaks,
or changes hands, the installer or an update breaks - so this is the list to check first when either
one fails, and the list to review when you care about what runs on your machine.

Scope: Fedora Asahi Remix 44+, aarch64. Everything below is fetched at install time or during
`omarchy-update`; nothing is vendored into this repository.

---

## 1. Fedora's own repositories

The default source for almost everything. Nothing special is configured.

| Repository | Used for |
|---|---|
| `fedora`, `updates` (Fedora 44, aarch64) | the bulk of the package set - Chromium, Waybar, Alacritty, SDDM, PipeWire, fonts, snapper, Docker, Java, and so on. See `install/omarchy-base.packages.fedora` and `install/omarchy-other.packages.fedora`. |

**Fedora 44 is required.** Several packages the older lists used no longer exist on 43, and the
Hyprland build Omarchy targets is only published for the 44 chroot. Every entry point stops on an
older release and prints the upgrade instructions.

## 2. COPR repositories

COPR is Fedora's user-contributed build service. These are third-party builds - they are not reviewed
by Fedora, and each one is a person who can stop maintaining it.

### Required - the install fails without them

| COPR | What it provides | Why we need it |
|---|---|---|
| [`lionheartp/Hyprland`](https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/) | `hyprland` (0.55.x), `hyprlock`, `hypridle`, `hyprsunset`, `hyprland-qt-support`, `xdg-desktop-portal-hyprland`, `uwsm` | Fedora does not ship Hyprland for aarch64. This is the build that works on Apple Silicon, and the only one with a Fedora 44 chroot. |
| [`atim/starship`](https://copr.fedorainfracloud.org/coprs/atim/starship/) | `starship` | prompt |
| [`atim/lazygit`](https://copr.fedorainfracloud.org/coprs/atim/lazygit/) | `lazygit` | git TUI |

### Optional - a failure here is not fatal

| COPR | What it provides | Notes |
|---|---|---|
| [`solopasha/hyprland`](https://copr.fedorainfracloud.org/coprs/solopasha/hyprland/) | `satty`, `hyprland-qtutils` | It also builds its own Hyprland. That is why it is pinned to `priority=90` and has an `excludepkgs` list: DNF must never mix its Hyprland with lionheartp's. |
| [`erikreider/swayosd`](https://copr.fedorainfracloud.org/coprs/erikreider/swayosd/) | `swayosd` | on-screen volume/brightness display; the only source |
| [`nclundell/fedora-extras`](https://copr.fedorainfracloud.org/coprs/nclundell/fedora-extras/) | `bluetui`, `bottom`, `lazydocker`, `nushell`, `yazi`, and others | assorted TUIs |
| [`scottames/ghostty`](https://copr.fedorainfracloud.org/coprs/scottames/ghostty/) | `ghostty` | only needed by `omarchy-install-terminal ghostty`. The default terminal is alacritty, so this must never be required - it used to be, pointing at a COPR that did not exist, and that alone killed every install. |

Both Hyprland COPRs build the same package names. `install/helpers/fedora-copr-protect.sh` is the one
place that defines the priority and exclude rules that keep them apart; the installer and the repair
migration both use it.

## 3. Built from source at install time

Not packaged for Fedora at all, in any repository or COPR. The installer compiles them, which is why
a first install takes a while.

| Software | Source | Version | Built with |
|---|---|---|---|
| Walker | <https://github.com/abenz1267/walker> | pinned `v2.16.2` | Rust / cargo |
| Elephant + its 10 provider plugins | <https://github.com/abenz1267/elephant> | pinned `v2.21.0` | Go (`-buildmode=plugin`) |

Both versions are pinned in `install/helpers/fedora-walker-elephant.sh` and recorded in a stamp at
`~/.local/state/omarchy/walker-elephant-version`. `omarchy-update` rebuilds them only when the pin
moves - nothing else can upgrade a source build. Elephant's providers are Go plugins and are
version-locked to the binary, so they are always rebuilt together with it.

| Software | Source | Version | Notes |
|---|---|---|---|
| `impala` (Wi-Fi TUI) | crates.io | pinned `0.7.3` | `cargo install` |
| `wiremix` (audio TUI) | crates.io | pinned `0.11.0` | `cargo install`; needs `pipewire-devel` |
| `grub-btrfs` | <https://github.com/Antynea/grub-btrfs> | default branch | snapshot boot entries |

## 4. Binaries and installers fetched over the network

These run code that is not in any package manager. They are listed here precisely because they
deserve a second look.

| What | Source | How |
|---|---|---|
| `mise` (runtime manager) | <https://mise.jdx.dev/install.sh> | **piped to a shell** |
| `uv` (Python tooling) | <https://astral.sh/uv/install.sh> | **piped to a shell**, upstream Omarchy's own step |
| `cliamp` (music TUI, optional) | <https://github.com/bjarneo/cliamp> | **piped to a shell**, pinned to tag `v1.57.1`, non-fatal on failure |
| `lazydocker` | GitHub releases (`jesseduffield/lazydocker`) | latest release tarball |
| `gum` (installer UI) | Fedora, with a GitHub release as fallback | dnf first. The old code went to GitHub first, with a pinned asset that no longer exists - every install started with a 404 and ran with no UI. |
| 1Password | <https://downloads.1password.com/linux/tar/stable/aarch64/> | only via `omarchy-install-1password` |
| LazyVim starter config | <https://github.com/LazyVim/starter> | `omarchy-lazyvim-setup` |
| Web app icons | `cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons` | PNGs for the installed web apps |

## 5. Flatpak

| Remote | Apps |
|---|---|
| [Flathub](https://flathub.org) | Typora (`io.typora.Typora`), LocalSend (`org.localsend.localsend_app`) |

## 6. Language runtimes and their package registries

| Manager | What comes from it |
|---|---|
| `mise` | node, bun, deno, zls (runtimes; **bun is not a Fedora package and never will be - it comes from mise**) |
| npm registry, via `omarchy-npx-install` wrappers | `@openai/codex`, `@google/gemini-cli`, `@github/copilot`, `@earendil-works/pi-coding-agent`, `@kitlangton/ghui`, `playwright` |
| pip (`--user`) | `terminaltexteffects` (install animations) |

## 7. [WARNING] Sources that point at the wrong project

Found while testing the installer end to end. Both predate the Fedora 44 work and are listed here
rather than quietly changed:

- `bin/omarchy-reinstall` clones **`malik-na/omarchy-mac`** (branch `fedora`) - a different, older
  repository - not `malik-na/omarchy-mac-fedora`. A user running it does not get this project back.
- `bin/omarchy-reinstall-git` clones **`basecamp/omarchy`** (branch `master`) and moves it over
  `$OMARCHY_PATH`. That is upstream's Arch tree: pacman package lists, no `.fedora` lists, no dnf
  helpers. On a Fedora machine it replaces a working install with one that cannot work.

## 8. What this repository does *not* use

No AUR, no `pacman`/`yay`/`paru`, no `mkinitcpio`, no `limine` - those are upstream Omarchy's, and
every path here goes through `dnf`, `rpm` and COPR instead. Boot and initramfs are `dracut` and
`grub-btrfs`. The terminal is `alacritty`, not ghostty. x86-only hardware support (NVIDIA, Intel,
Dell, ASUS, Lenovo, Framework) is present but never wired in: it is guarded by `omarchy-hw-*` checks
that cannot match on Apple Silicon.
