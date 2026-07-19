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
| [`lionheartp/Hyprland`](https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/) | `hyprland` (0.55.x) or `hyprland-git`, `hyprsunset`, `hyprpicker`, `hyprland-qt-support`, `hyprland-guiutils`, `xdg-desktop-portal-hyprland`, `uwsm`, `gpu-screen-recorder` | Fedora does not ship Hyprland for aarch64. This is the build that works on Apple Silicon, and the only one with a Fedora 44 chroot. It is pinned to `priority=10` (with core GTK/Pango/Cairo excluded) so dnf prefers it for exactly these packages. |
| [`atim/starship`](https://copr.fedorainfracloud.org/coprs/atim/starship/) | `starship` | prompt |
| [`atim/lazygit`](https://copr.fedorainfracloud.org/coprs/atim/lazygit/) | `lazygit` | git TUI |

### Optional - a failure here is not fatal

| COPR | What it provides | Notes |
|---|---|---|
| [`nclundell/fedora-extras`](https://copr.fedorainfracloud.org/coprs/nclundell/fedora-extras/) | `lazydocker`, `bottom`, `nushell`, `yazi`, and others | assorted TUIs |
| [`scottames/ghostty`](https://copr.fedorainfracloud.org/coprs/scottames/ghostty/) | `ghostty` | only needed by `omarchy-install-terminal ghostty`. The default terminal is alacritty, so this must never be required - it used to be, pointing at a COPR that did not exist, and that alone killed every install. |

The compositor package is chosen at install time by `install/helpers/fedora-hyprland.sh`, not listed
in `omarchy-base.packages.fedora`. `lionheartp/Hyprland` builds stable `hyprland` once per release
but rebuilds `hyprutils`/`aquamarine` continuously, so an soname bump leaves stable uninstallable
until it is rebuilt (0.55.4, built 2026-06-11, broke on the 2026-07-18 library rebuilds). The helper
prefers stable and falls back to `hyprland-git`, which is rebuilt daily against the current
libraries. The two packages conflict, so exactly one is installed. `omarchy-update-manual-pkgs` runs
the helper on every update, so a machine on the fallback returns to stable unattended once the COPR
catches up.

Two COPRs the 3.8.x line used are gone on purpose: `solopasha/hyprland` (unmaintained - no builds
since 2025-10 - and its only contribution, satty, is retired by quattro) and `erikreider/swayosd`
(swayosd is retired by quattro; the shell draws the OSD). `install/helpers/fedora-copr-protect.sh`
lists both as dead repos so upgrades remove them from existing installs.

### Vendor repositories - added only when the user opts in

| Repository | Provides | Added by |
|---|---|---|
| [`repo.nordvpn.com`](https://repo.nordvpn.com/yum/nordvpn/centos/) | `nordvpn` | `omarchy-install-service-nordvpn` |

Not a COPR and not enabled by default: nothing installs it until the user picks NordVPN from the
menu. NordVPN supports Fedora 32+ officially and publishes aarch64 builds. Their documented method
pipes an install script into a shell and then installs with `--nogpgcheck`; the repository is
signed, so the command writes the repo file itself and leaves `gpgcheck=1` on.

## 3. Built from source at install time

The 3.8.x line compiled walker, elephant, impala and wiremix here; quattro retires all of them in
favour of the Quickshell shell, so the only source build left is:

| Software | Source | Version | Notes |
|---|---|---|---|
| `grub-btrfs` | <https://github.com/Antynea/grub-btrfs> | default branch | snapshot boot entries |

### quattro's first-party tools

quattro adds first-party tools that ship as Arch packages upstream (built from
`omacom-io/omarchy-pkgs`); none are Fedora packages. `install/helpers/fedora-first-party.sh` installs
them from the aarch64 sources below - release binaries or source builds, version-pinned and stamped
under `~/.local/state/omarchy/first-party` so re-runs and `omarchy-update-manual-pkgs` only act on a
bump. Recipes track the upstream `omacom-io/omarchy-pkgs` PKGBUILDs. Binaries land in `/usr/local/bin`.

| Tool | aarch64 source | Mechanism |
|---|---|---|
| `aether` (wallpaper theming) | [`bjarneo/aether`](https://github.com/bjarneo/aether) v4.27.2 | prebuilt `aether-linux-arm64` + `aether-wp-linux-arm64` |
| `omacut` (video trimmer) | [`omacom-io/omacut`](https://github.com/omacom-io/omacut) v0.1.2 | Qt6 source build (`./bin/build`) |
| `omawrite` (Markdown editor) | [`omacom-io/omawrite`](https://github.com/omacom-io/omawrite) v0.2.0 | Qt6 source build (`./bin/build`) |
| `tensaku` (screenshot annotation) | [`jondkinney/tensaku`](https://github.com/jondkinney/tensaku) v0.26.6 | prebuilt `tensaku-v0.26.6-aarch64.tar.gz` |
| `cliamp` (music player) | [`bjarneo/cliamp`](https://github.com/bjarneo/cliamp) v1.57.1 | prebuilt `cliamp-linux-arm64` (codecs statically linked) |
| `voxtype` (dictation) | [`peteonrails/voxtype`](https://github.com/peteonrails/voxtype) v0.7.5 | prebuilt `…-aarch64-cpu` (v1.0+ dropped Linux aarch64) |
| `tobi-try` (`try`) | [`tobi/try`](https://github.com/tobi/try) v1.8.1 | Ruby script from a pinned commit (needs `ruby`) |
| `hyprland-preview-share-picker` | [`WhySoBad/hyprland-preview-share-picker`](https://github.com/WhySoBad/hyprland-preview-share-picker) v0.2.1 | cargo source build (links a pinned `hyprland-protocols`) |

The share-picker is xdg-desktop-portal-hyprland's `custom_picker_binary` (see `config/hypr/xdph.conf`).
Its cargo build pulls the gtk4-rs stack and is memory-heavy: a parallel release build needs several GB
of RAM to link (a 4-core build wanted about 6 GB in a container - 2 GB is not enough even single-job),
so a low-memory machine should add swap or reduce cargo jobs. Runtime libraries for all of these tools
are ordinary Fedora packages and are listed in `install/omarchy-base.packages.fedora` under
"First-party tool runtime deps".

`asdcontrol` (upstream's Apple Studio Display / Pro Display XDR brightness tool) is **dropped**: it
only drives external Apple displays over USB, which an Asahi laptop's built-in panel never uses.

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
| Fedora repos, every COPR, and the opt-in NordVPN repo | `dnf upgrade` |
| The Hyprland core (`hyprland` or `hyprland-git`) | `install/helpers/fedora-hyprland.sh`, re-run from `omarchy-update-manual-pkgs`. `dnf upgrade` cannot do this on its own: moving off the fallback means swapping to a differently-named package that conflicts with the installed one. |
| Flatpak apps (Typora, LocalSend, Obsidian, Moonlight) | `flatpak update --user`, in `omarchy-update-manual-pkgs`. Upstream gets these from the AUR, so `yay -Sua` swept them up; on Fedora nothing was updating them at all until this step existed. |
| First-party tools (aether, cliamp, omacut, omawrite, tensaku, voxtype, tobi-try, share-picker) | `install/helpers/fedora-first-party.sh`, re-run from `omarchy-update-manual-pkgs`. It is version-pinned and stamped, so it only redownloads or rebuilds a tool when its pin in that script moves. |
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
