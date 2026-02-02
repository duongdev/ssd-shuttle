# Shuttle shell integration for Zsh
# Add to .zshrc: source ~/.ssd-shuttle/shuttle-init.zsh

# Detect shuttle directory from this script's location
SHUTTLE_DIR="${0:A:h}"

# Add completions to fpath
fpath=("$SHUTTLE_DIR/completions" $fpath)

# Rebuild completion cache if shuttle completion is missing
if [[ ! -f ~/.zcompdump ]] || ! grep -q '_shuttle' ~/.zcompdump 2>/dev/null; then
    autoload -Uz compinit && compinit
else
    autoload -Uz compinit && compinit -C
fi

# Warp terminal completions (uses YAML specs instead of zsh completions)
if [[ -n "$WARP_TERMINAL" ]] && [[ -f "$SHUTTLE_DIR/completions/shuttle.yaml" ]]; then
    mkdir -p ~/.warp/completions 2>/dev/null
    ln -sf "$SHUTTLE_DIR/completions/shuttle.yaml" ~/.warp/completions/shuttle.yaml 2>/dev/null
fi

# Health check on shell startup (async to not slow down shell)
shuttle-health-check() {
    local shuttle_bin="$SHUTTLE_DIR/shuttle"

    if [[ -x "$shuttle_bin" ]]; then
        local result
        result=$("$shuttle_bin" health --quiet 2>/dev/null)
        if [[ -n "$result" ]]; then
            echo "$result"
        fi
    fi
}

# Run health check in background, show result if issues
{
    sleep 1  # Delay slightly to not interfere with prompt
    shuttle-health-check
} &!
