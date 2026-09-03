-- Shared path constants for Omarchy's Hyprland Lua modules.
-- Lua files loaded with require() have separate local scopes, so modules that
-- need these paths import this table instead of repeating os.getenv() lookups.

local home = os.getenv("HOME")

return {
  home = home,
  config_home = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config"),
  state_home = os.getenv("XDG_STATE_HOME") or (home .. "/.local/state"),
  -- The fork is a per-user git clone, not a system package, so fall back to that location rather
  -- than the Arch package path when OMARCHY_PATH is not in the session environment.
  omarchy_path = os.getenv("OMARCHY_PATH") or (home .. "/.local/share/omarchy"),
}
