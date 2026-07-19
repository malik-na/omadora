#!/bin/bash
# Install-time presentation, ported from the 3.8.x installer: the centered
# Omarchy logo, the gum styling, and the live tail of the install log that
# renders under the logo while the logged steps run. Sourced by install.sh
# after helpers/fedora-gum.sh, so gum is available.

# Terminal size from /dev/tty (works direct, sourced, or piped).
if [[ -e /dev/tty ]]; then
  TERM_SIZE=$(stty size 2>/dev/null </dev/tty)
  if [[ -n $TERM_SIZE ]]; then
    TERM_HEIGHT=$(echo "$TERM_SIZE" | cut -d' ' -f1)
    TERM_WIDTH=$(echo "$TERM_SIZE" | cut -d' ' -f2)
  else
    TERM_WIDTH=80
    TERM_HEIGHT=24
  fi
else
  TERM_WIDTH=80
  TERM_HEIGHT=24
fi
export TERM_WIDTH TERM_HEIGHT

export LOGO_PATH="$OMARCHY_PATH/logo.txt"
LOGO_WIDTH=$(awk '{ if (length > max) max = length } END { print max+0 }' "$LOGO_PATH" 2>/dev/null || echo 0)
LOGO_HEIGHT=$(wc -l <"$LOGO_PATH" 2>/dev/null || echo 0)
export LOGO_WIDTH LOGO_HEIGHT

PADDING_LEFT=$(((TERM_WIDTH - LOGO_WIDTH) / 2))
((PADDING_LEFT < 0)) && PADDING_LEFT=0
PADDING_LEFT_SPACES=$(printf "%*s" "$PADDING_LEFT" "")
export PADDING_LEFT PADDING_LEFT_SPACES

# Tokyo Night theme for gum confirm
export GUM_CONFIRM_PROMPT_FOREGROUND="6"     # Cyan for prompt
export GUM_CONFIRM_SELECTED_FOREGROUND="0"   # Black text on selected
export GUM_CONFIRM_SELECTED_BACKGROUND="2"   # Green background for selected
export GUM_CONFIRM_UNSELECTED_FOREGROUND="7" # White for unselected
export GUM_CONFIRM_UNSELECTED_BACKGROUND="0" # Black background for unselected
export PADDING="0 0 0 $PADDING_LEFT"         # Gum Style
export GUM_CHOOSE_PADDING="$PADDING"
export GUM_FILTER_PADDING="$PADDING"
export GUM_INPUT_PADDING="$PADDING"
export GUM_SPIN_PADDING="$PADDING"
export GUM_TABLE_PADDING="$PADDING"
export GUM_CONFIRM_PADDING="$PADDING"

clear_logo() {
  printf "\033[H\033[2J" # Clear screen and move cursor to top-left
  gum style --foreground 2 --padding "1 0 0 $PADDING_LEFT" "$(<"$LOGO_PATH")"
}

# Live view of the install log: a background loop re-renders the last 20 log
# lines at the saved cursor position while the logged steps run.
start_log_output() {
  local ANSI_SAVE_CURSOR="\033[s"

  printf "%b" "$ANSI_SAVE_CURSOR"
  printf "%b" "$ANSI_HIDE_CURSOR"

  (
    local ANSI_RESTORE_CURSOR="\033[u"
    local ANSI_CLEAR_LINE="\033[2K"
    local ANSI_RESET="\033[0m"
    local ANSI_GRAY="\033[90m"
    local log_lines=20
    local max_line_width=$((LOGO_WIDTH - 4))
    local output line i

    while true; do
      mapfile -t current_lines < <(tail -n $log_lines "$OMARCHY_INSTALL_LOG_FILE" 2>/dev/null)

      output=""
      for ((i = 0; i < log_lines; i++)); do
        line="${current_lines[i]:-}"

        if ((${#line} > max_line_width)); then
          line="${line:0:$max_line_width}..."
        fi

        if [[ -n $line ]]; then
          output+="${ANSI_CLEAR_LINE}${ANSI_GRAY}${PADDING_LEFT_SPACES}  → ${line}${ANSI_RESET}\n"
        else
          output+="${ANSI_CLEAR_LINE}${PADDING_LEFT_SPACES}\n"
        fi
      done

      printf "${ANSI_RESTORE_CURSOR}%b" "$output"

      sleep 0.1
    done
  ) &
  monitor_pid=$!
}

stop_log_output() {
  if [[ -n ${monitor_pid:-} ]]; then
    kill "$monitor_pid" 2>/dev/null || true
    wait "$monitor_pid" 2>/dev/null || true
    unset monitor_pid
  fi
}
