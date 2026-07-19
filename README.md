# Omarchy Mac Fedora — Quattro

A concise, beginner-friendly guide to install Omarchy Mac Fedora on **Fedora Asahi Remix (aarch64)** for Apple Silicon Macs M1/M2

> ### 🆕 This is Omarchy "Quattro"
> This branch tracks **Omarchy quattro** — a major rework of the desktop. The bar, launcher,
> notifications, and OSD (waybar / walker / mako / swayosd) are replaced by a single **Quickshell**
> shell, and all Hyprland config — including every keybinding — moves to **Lua** (`.conf` → `.lua`).
> **→ See [QUATTRO-CHANGES.md](QUATTRO-CHANGES.md) for the full list of what changed.**
> For the previous 3.8.x line, use the `sync/upstream-v3.8.2` branch.

_This project is an extension of [Omarchy Mac](https://github.com/malik-na/omarchy-mac) project._

**Important:** Fedora Asahi Minimal first boot lands in a TTY setup flow. You must complete all prompts there before running Omarchy Mac Fedora installer steps.

[![License](https://img.shields.io/github/license/malik-na/omarchy-mac-fedora)](LICENSE) [![Stars](https://img.shields.io/github/stars/malik-na/omarchy-mac-fedora?style=social)](https://github.com/malik-na/omarchy-mac-fedora/stargazers)

---

## Quick links

- Fedora Asahi device support: https://asahilinux.org/fedora/#device-support
- Omarchy Mac Fedora Discord: https://discord.gg/jdqjcPxxJe
- External monitor discussion: https://github.com/malik-na/omarchy-mac-fedora/discussions/73
- Support the project: https://buymeacoffee.com/malik2015no

---

## Before you begin

Requirements:

- Apple Silicon Mac (M1/M2 family)
- **Fedora Asahi Remix 44 Minimal (aarch64) or newer**
- A regular user with sudo access
- Internet connectivity
- `git` installed

Unsupported targets:

- Arch/Asahi Alarm runtime paths
- Non-Asahi Fedora installs
- x86_64
- **Fedora Asahi Remix 43 and older** - see below

### Already on Fedora Asahi Remix 43?

Omarchy 3.8.2 requires Fedora 44. Several packages it needs no longer exist on 43, and the Hyprland
0.55 build it targets is only published for the 44 chroot. Upgrade Fedora first:

```bash
sudo dnf upgrade --refresh
sudo dnf install dnf-plugin-system-upgrade
sudo dnf system-upgrade download --releasever=44
sudo dnf system-upgrade reboot
```

The machine reboots into the upgrade, so close your work first. When it comes back up, run
`omarchy-update`.

Omarchy never runs the system upgrade for you: it reboots the machine and can leave an Asahi install
unbootable, so it is your call, not the installer's. Until you upgrade, the installer, `omarchy-update`
and `omarchy-migrate` all stop with these instructions and change nothing - an existing Fedora 43
install keeps working on the Omarchy version it already has.

Checklist:

- [ ] Backup completed
- [ ] Fedora Asahi device compatibility checked
- [ ] Running Fedora Asahi Remix 44 or newer (`cat /etc/os-release`)
- [ ] Fedora Asahi first-boot TTY setup completed (language, hostname, time, root password, user, wheel)
- [ ] Internet connected
- [ ] Sudo user ready

---

## Connect to Wi-Fi before installation

Use one of these methods from your Fedora Asahi session before running the installer.

### Option 1: `nmcli` (NetworkManager CLI)

```bash
# Check network devices
nmcli device status

# Connect to a network
nmcli device wifi connect "SSID_NAME" password "PASSWORD"
```

### Option 2: `iwctl` (iwd)

```bash
iwctl
# inside iwctl:
# device list
# station wlan0 scan
# station wlan0 get-networks
# station wlan0 connect "SSID_NAME"
# exit
```

If `wlan0` does not exist on your system, replace it with your detected wireless interface name.

Fedora Asahi Minimal normally includes the required first-boot setup prompts; use these commands only to ensure networking is ready before install.

---

### Prepare Fedora Asahi Minimal (required)

Fedora Asahi Minimal always starts with a TTY setup flow. Complete all prompts there before continuing:

- language
- hostname
- date/time
- root password
- regular user creation
- wheel/sudo access

Do not continue to Omarchy install until all first-boot setup actions are complete.

Optional: improve TTY readability

```bash
sudo dnf install -y terminus-fonts-console || sudo dnf install -y terminus-fonts
sudo setfont ter-v22n
```

### Install Omarchy Mac Fedora

As your regular sudo user, either run the one-line bootstrap:

```bash
wget -qO- https://raw.githubusercontent.com/eightscrow/omarchy-mac-fedora-quattro/quattro/boot.sh | bash
```

or clone and run the installer yourself:

```bash
sudo dnf update
git clone -b quattro https://github.com/eightscrow/omarchy-mac-fedora-quattro.git ~/.local/share/omarchy
cd ~/.local/share/omarchy
bash install.sh
```

---

## Post-install tasks

- Reboot and log into your Hyprland session.
- Press `Cmd + K`  to learn all the Keybindings. 
- Validate core desktop behavior: app launcher opens, terminal keybind works, Wi-Fi/Bluetooth menus open, and lock screen works.

## Troubleshooting and FAQ

### Installer refuses to continue

The installer currently supports **Fedora Asahi Remix on aarch64 only**. Verify distro/architecture and rerun.

On **Fedora Asahi Remix 43 or older** the installer, `omarchy-update` and `omarchy-migrate` all stop on purpose and print the upgrade steps. Upgrade Fedora to 44 first - see [Already on Fedora Asahi Remix 43?](#already-on-fedora-asahi-remix-43) above.

### Session launches but keybinds fail

Run this to confirm Omarchy commands resolve in your login shell:

```bash
bash -lc 'echo "$PATH"'
bash -lc 'command -v omarchy-menu omarchy-cmd-terminal-cwd uwsm-app'
```

---

## Update and maintenance

- `Menu > Update > Omarchy` pulls the Omarchy repository, runs any pending migrations, and updates Fedora packages (`dnf upgrade --refresh`).
- It also covers what `dnf` cannot reach: the `--user` Flatpak apps (Obsidian, Moonlight), the npx-wrapped CLI tools, and the mise runtimes. `DEPENDENCIES.md` lists every external source and the mechanism that updates it.
- Update availability is tracked as git divergence from your configured upstream branch.

Check branch/upstream state:

```bash
git -C ~/.local/share/omarchy status -sb
```

---

## Support

Need help or want to share your setup?

- Discord: https://discord.gg/jdqjcPxxJe
- Support the project: [![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/malik2015no)

---

## External resources

- Fedora Asahi device support: https://asahilinux.org/fedora/#device-support
- Asahi Linux project: https://asahilinux.org/
- External monitor discussion: https://github.com/malik-na/omarchy-mac-fedora/discussions/73

---

## Acknowledgements

Thanks to the Asahi Linux community for making Linux  by possible on Macs and thanks to DHH for Omarchy.

If this project helped you, please star the repository and share feedback on X by tagging [@tiredkebab](https://x.com/tiredkebab).

---

