# Omarchy update process

This document describes the update behavior of this fork, which ships by **git clone** rather than
as a distribution package. Upstream Omarchy is package-backed on Arch and can therefore treat a
`pacman -Syu` as an Omarchy update; here the two are separate things:

- **Omarchy itself** lives in a checkout at `$OMARCHY_PATH` (`~/.local/share/omarchy`) and updates
  by pulling its branch.
- **System packages** come from dnf and update independently.

`omarchy update` is what ties them together, and it is the only path that runs migrations.

The design goals:

- `omarchy update` owns the visible pipeline: git pull, package transaction, migrations,
  post-update hooks, update-state refresh, and restart checks.
- Migrations run per-user after the package transaction, because they may need `$HOME`, DBus or
  session state, a graphical session, sudo, or user interaction.
- A user who upgrades packages directly with dnf gets no Omarchy update at all, and is nudged by a
  notification when migrations are pending.

## State and coordination files

| Path | Owner | Purpose |
| --- | --- | --- |
| `${XDG_RUNTIME_DIR:-/tmp}/omarchy-update.lock` | user | Prevent overlapping update runs. Owned by `omarchy-update`; compatibility wrappers inherit/respect it. |
| `/tmp/omarchy-update.log` | user | Transcript of `omarchy update`, used by `omarchy-update-analyze-logs`. |
| `/tmp/omarchy-kernel-before` | user | Kernel version recorded before the transaction so `omarchy-update-restart` can tell whether the kernel moved. |
| `~/.local/state/omarchy/current/` | user | Generated active theme, selected theme name, and current background symlink. |
| `~/.local/state/omarchy/migrations/` | user | Per-user migration markers. |
| `~/.local/state/omarchy/first-party/` | user | Version stamps for the first-party tools installed outside dnf. |
| `~/.local/state/omarchy/reboot-required` | user | Optional reboot marker checked by `omarchy-update-restart`. |
| `~/.local/state/omarchy/restart-*-required` | user | Optional service/app restart markers checked by `omarchy-update-restart`. |

## Migration layout

See [`migrations.md`](migrations.md) for the full migration model, authoring guidelines, and
troubleshooting notes.

Migrations live in:

```text
migrations/*.sh
```

They run as the current user through:

```bash
omarchy-migrate
```

Completion state is per-user:

```text
~/.local/state/omarchy/migrations/<migration filename>
```

Every user gets a chance to run every migration. Migrations run as the user; privileged work should
invoke the appropriate helper or privilege prompt. Migrations must be idempotent; if one user
already applied a machine-wide repair, the migration should no-op for other users.

Two things are specific to this fork:

- A fresh install is not expected to replay history. `omarchy-finalize-user --first-install` stamps
  every migration present at install time, so only migrations added afterwards ever run.
- Migrations written for Arch are skipped rather than failed. `omarchy-migrate` detects pacman, yay,
  mkinitcpio, limine and similar markers and records them under
  `~/.local/state/omarchy/migrations/skipped/`.

For watchers and diagnostics, `omarchy-migrate --pending` prints pending migration names and exits
`0` when any are pending. When no migrations are pending, it prints nothing and exits non-zero.

## Path 1: `omarchy update`

High-level flow:

```text
omarchy-update
  ├─ ensure transcript logging through script(1) → /tmp/omarchy-update.log
  ├─ stop with upgrade instructions if the release is older than Fedora 44
  ├─ confirm unless -y
  ├─ create snapper snapshot, if snapper is installed
  ├─ omarchy-update-git          (fetch + pull --autostash, refresh the version file)
  └─ omarchy-update-perform
       ├─ tag the terminal noidle so the session does not sleep mid-update
       ├─ omarchy-update-time
       ├─ omarchy-update-keyring        (no-op on Fedora; rpm owns repository keys)
       ├─ record the running kernel version → /tmp/omarchy-kernel-before
       ├─ omarchy-update-available-reset
       ├─ omarchy-update-system-pkgs    (dnf upgrade --refresh, then dnf autoremove)
       ├─ omarchy-migrate
       ├─ omarchy-update-manual-pkgs    (Hyprland core choice, Flatpaks, first-party tools)
       ├─ omarchy-hook post-update
       ├─ omarchy-update-analyze-logs
       ├─ omarchy-update-restart
       └─ clear the noidle tag
```

Important behavior:

- The git pull happens **before** the package transaction, so migrations added upstream are present
  by the time `omarchy-migrate` runs.
- `omarchy-update-manual-pkgs` covers everything dnf cannot reach on its own: the Flatpak apps, the
  first-party tools built or downloaded outside dnf, and the choice between `hyprland` and
  `hyprland-git` (see [`../DEPENDENCIES.md`](../DEPENDENCIES.md)).
- A failure should leave enough output in `/tmp/omarchy-update.log` and the terminal transcript to
  debug.

## Path 2: direct `sudo dnf upgrade`

Upstream guards `pacman -Syu` with an ALPM hook and redirects the user back to `omarchy update`.
dnf has no equivalent hook mechanism, and this fork ships no guard: a direct `dnf upgrade` simply
succeeds.

What it does and does not do:

```text
sudo dnf upgrade
  ├─ upgrades Fedora packages, including the Hyprland stack
  ├─ does NOT touch the Omarchy checkout, so no new migrations arrive
  └─ does NOT run migrations, hooks, or restart checks
```

The consequence is milder than on Arch. Because Omarchy is a checkout rather than a package, a
direct dnf upgrade cannot deliver Omarchy changes at all, so it cannot leave the system with new
migrations pending. Pending migrations only appear after an `omarchy-update-git` pull.

The notification path still exists for that case:

- `omarchy-update-user-notify.path` watches the migration state directory and triggers
  `omarchy-migrate-notify`.
- `omarchy-first-run` enables the path unit and also invokes `omarchy-migrate-notify` on graphical
  startup, so a user who updated before the unit existed still gets prompted.
- The notifier is only a prompt. It does not run migrations in the background.

## Shell update indicator

The bar widget `omarchy.system-update` runs:

```bash
omarchy-update-available
```

Upstream checks whether the installed `omarchy` package has a newer version. Here there is no
package, so the check is a git comparison: it counts how far `HEAD` is behind the checkout's
upstream branch.

Exit codes:

- `0` — updates are available; stdout names how many commits behind which branch.
- non-zero — up to date; stdout names the current branch and short commit.

The widget runs this check on shell startup and every six hours. Clicking the update icon launches
`omarchy-update` in a floating terminal. `omarchy-update-available-reset` clears the indicator
through the shell's IPC (`omarchy-shell -q omarchy.system-update clear`).

## Update-related binaries

| Binary | Current purpose | Keep? / Question |
| --- | --- | --- |
| `omarchy-update` | Public user command. Adds transcript logging, the Fedora 44 gate, confirmation, snapshot, the git pull, and the update pipeline. | **Keep.** The blessed entry point. |
| `omarchy-update-git` | Fetches and pulls the checkout with `--autostash`, then refreshes `version` from the highest merged release tag. | **Keep.** This is the fork's equivalent of the package transaction that delivers Omarchy itself. |
| `omarchy-update-perform` | Runs the pipeline itself. Still callable directly by older callers. | **Keep.** No longer only a compatibility wrapper here - `omarchy-update` delegates the whole pipeline to it. |
| `omarchy-update-confirm` | Gum confirmation copy for `omarchy update`. | **Question.** Could be inlined; a separate file only keeps the copy isolated. |
| `omarchy-update-keyring` | Prints that Fedora manages repository keys through rpm metadata and exits. | **Question.** A deliberate no-op kept so upstream's pipeline shape still reads correctly. It costs one line of output per update. |
| `omarchy-update-system-pkgs` | Runs `dnf upgrade -y --refresh`, then `dnf autoremove -y`. | **Keep.** Small leaf command, clear and testable. |
| `omarchy-migrate` | Public migration command. Runs all pending migrations for the current user, skipping Arch-only ones. Supports `--pending`. | **Keep.** |
| `omarchy-migrate-notify` | Notification helper. Uses `omarchy-migrate --pending` and notifies only when this user has pending migrations. | **Keep internal/hidden.** |
| `omarchy-update-user-notify` | Hidden compatibility wrapper for `omarchy-migrate-notify`. | **Temporary.** Keep only for old callers. |
| `omarchy-update-manual-pkgs` | Everything dnf cannot reach: the Hyprland core choice, Flatpak apps, and the first-party tools. Stamp-guarded, so it is a no-op until a pin moves. | **Keep.** This is the fork's counterpart to upstream's `yay -Sua`. |
| `omarchy-update-available` | Update checker for the shell widget, comparing the checkout against its upstream branch. | **Keep.** |
| `omarchy-update-available-reset` | Clears the shell's update indicator through `omarchy-shell -q`. | **Keep.** |
| `omarchy-update-mise` | Runs `mise up` for mise-managed tools. | **Question.** Present, but **not** part of the pipeline: `omarchy-update-perform` does not call it. Either wire it in or drop it. |
| `omarchy-update-analyze-logs` | Scans `/tmp/omarchy-update.log` for known failure patterns. | **Keep/expand.** Useful safety net; should grow only for high-signal checks. |
| `omarchy-update-restart` | Prompts for reboot after kernel/Hyprland updates and restarts components with `restart-*-required` markers. | **Keep.** |
| `omarchy-update-firmware` | Manual firmware update command using fwupd. Not part of the normal pipeline. | **Keep separate.** |
| `omarchy-update-time` | Restarts `systemd-timesyncd`. | **Question.** Not really an update command. Consider moving under system/time maintenance. |

## Closed decisions

1. **Omarchy updates come from the checkout, not from a package**
   - `omarchy-update-git` pulls the branch; there is no `omarchy` rpm to upgrade.
   - The update indicator is therefore a commit comparison, not a version comparison.

2. **Migrations run per-user from the update pipeline**
   - `omarchy update` runs `omarchy-migrate` after the package transaction.
   - A fresh install stamps existing migrations rather than replaying them.
   - Arch-only migrations are recorded as skipped instead of failing the update.

3. **Migration notification naming**
   - The real helper is `omarchy-migrate-notify`.
   - `omarchy-update-user-notify` remains only as a hidden compatibility wrapper.

4. **No pacman guard**
   - The ALPM hook and `omarchy-update-pacman-guard` were removed: dnf has no equivalent hook, and
     a direct `dnf upgrade` cannot deliver Omarchy changes anyway.

5. **Orphan cleanup is part of the package step**
   - `dnf autoremove` runs inside `omarchy-update-system-pkgs`; there is no separate orphan command.

## Remaining concerns

1. **`.rpmnew` / `.rpmsave` handling is missing**
   - The Fedora counterpart of upstream's pacnew concern. dnf leaves these behind when a package
     ships a changed config file that was edited locally, and nothing currently surfaces them after
     an update.

2. **A direct `dnf upgrade` can move the Hyprland stack without Omarchy noticing**
   - The compositor and its libraries come from a COPR that rebuilds continuously. Upgrading them
     outside `omarchy update` skips `omarchy-update-manual-pkgs`, which is what would otherwise
     reconcile the `hyprland` / `hyprland-git` choice.

3. **`omarchy-update-mise` is orphaned**
   - It exists and works, but nothing calls it. Decide whether mise-managed tools belong in the
     blessed update path.
