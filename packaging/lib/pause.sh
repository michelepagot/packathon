# shellcheck shell=bash
# =============================================================================
# pause.sh: shared helpers for step-by-step build/demo scripts.
#
# Source this file from a script that has already run `set -euo pipefail`.
# It defines three functions:
#   pause_prompt <msg>   wait for [Enter] when PAUSE_MODE=true
#   print_command_box <cmd>   render the "Command to Run" box
#   demo_cmd <cmd> [desc] [comment]   print box, pause, execute (or dry-run)
#
# The caller is responsible for:
#   - PAUSE_MODE (true/false)  -- pause_prompt is a no-op unless it is "true"
#   - DRY_RUN  (true/false)    -- demo_cmd short-circuits when it is "true"
#
# Color variables (BOLD, GREEN, YELLOW, CYAN, DIM, RESET) are used by the
# box rendering. If the caller has not defined them (e.g. a build script that
# does not do colored output), sensible TTY-aware defaults are provided here.
# =============================================================================

# TTY-aware color fallbacks; a caller that already set these keeps its values.
if [ -t 1 ]; then
    : "${BOLD:=\033[1m}"
    : "${GREEN:=\033[1;32m}"
    : "${YELLOW:=\033[1;33m}"
    : "${CYAN:=\033[1;36m}"
    : "${DIM:=\033[2m}"
    : "${RESET:=\033[0m}"
else
    : "${BOLD:=}"
    : "${GREEN:=}"
    : "${YELLOW:=}"
    : "${CYAN:=}"
    : "${DIM:=}"
    : "${RESET:=}"
fi

# pause_prompt <msg>
# Print <msg> and wait for [Enter] when PAUSE_MODE=true. Reads from /dev/tty
# when available so it works even if the script's stdin is redirected.
pause_prompt() {
    local prompt_msg="${1:-}"
    if [ "${PAUSE_MODE:-false}" = true ]; then
        echo -ne "${prompt_msg}"
        if [ -c /dev/tty ] && [ -r /dev/tty ]; then
            read -s -r _ < /dev/tty 2>/dev/null || read -s -r _ 2>/dev/null || true
        else
            read -s -r _ 2>/dev/null || read -r _ 2>/dev/null || true
        fi
        printf "\r\033[2K"
    fi
}

# print_command_box <cmd>
# Render the "Command to Run" box around <cmd>.
print_command_box() {
    local cmd="$1"
    echo ""
    echo -e "  ${CYAN}┌──[ Command to Run ]──────────────────────────────────────────────────${RESET}"
    echo -e "  ${BOLD}${YELLOW}${cmd}${RESET}"
    echo -e "  ${CYAN}└──────────────────────────────────────────────────────────────────────${RESET}"
}

# demo_cmd <cmd> [desc] [comment]
# Print an optional substep header, render the command box, then either
# (DRY_RUN=true) stop after the box, or (DRY_RUN=false) pause, execute, and
# pause again. A trailing comment is printed after the box/output.
demo_cmd() {
    local cmd="$1"
    local desc="${2:-}"
    local comment="${3:-}"

    if [ -n "${desc}" ] && declare -F substep >/dev/null 2>&1; then
        substep "${desc}"
    fi

    echo ""
    echo -e "  ${CYAN}┌──[ Command to Run ]──────────────────────────────────────────────────${RESET}"
    echo -e "  ${BOLD}${YELLOW}${cmd}${RESET}"

    if [ "${DRY_RUN:-false}" = true ]; then
        echo -e "  ${CYAN}└──────────────────────────────────────────────────────────────────────${RESET}"
        if [ -n "${comment}" ]; then
            echo -e "${comment}"
        fi
        return 0
    fi

    echo -e "  ${CYAN}├──[ Output ]──────────────────────────────────────────────────────────${RESET}"
    pause_prompt "  ${BOLD}${GREEN}[PAUSE]${RESET} Press ${BOLD}[Enter]${RESET} to execute (or Ctrl+C to stop)... "
    eval "${cmd}" || true
    echo -e "  ${CYAN}└──────────────────────────────────────────────────────────────────────${RESET}"

    if [ -n "${comment}" ]; then
        echo -e "${comment}"
    fi

    pause_prompt "  ${BOLD}${GREEN}[PAUSE]${RESET} Press ${BOLD}[Enter]${RESET} to continue (or Ctrl+C to stop)... "
}
