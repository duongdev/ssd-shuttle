# Shuttle shell integration for Zsh
# Add to .zshrc: source ~/personal/ssd-shuttle/shuttle-init.zsh

# Add completions to fpath
fpath=(~/personal/ssd-shuttle/completions $fpath)
autoload -Uz compinit && compinit -C

# Health check on shell startup (async to not slow down shell)
shuttle-health-check() {
    local shuttle_bin="${HOME}/personal/ssd-shuttle/shuttle"

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
