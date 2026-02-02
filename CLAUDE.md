# Shuttle - AI Assistant Context

## Project Overview

Shuttle is a macOS tool for seamlessly moving directories between internal and external SSDs using symlinks. It consists of:

1. **CLI Tool** (`shuttle`) - Bash script for terminal usage
2. **Raycast Extension** - TypeScript/React GUI for quick access

## Architecture

### CLI (`shuttle`)

- **Language**: Bash
- **Config**: `~/.config/shuttle/config` (shell variables)
- **Manifest**: `~/.config/shuttle/manifest.json` (tracks offloaded items)
- **Storage**: `$SSD_PATH/$STORAGE_DIR/` preserves relative paths from `$HOME`

Key functions:
- `cmd_offload()` - Move dir to SSD, create symlink
- `cmd_restore()` - Move back, remove symlink
- `cmd_health()` - Verify SSD + symlinks
- `confirm_action()` - Respects `CONFIRM` env var override

### Raycast Extension (`raycast-extension/`)

- **Language**: TypeScript + React
- **Framework**: Raycast API
- **Entry points**: `index.tsx`, `offload.tsx`, `restore.tsx`, `health.tsx`
- **Shared logic**: `utils.ts`

Key considerations:
- **No slow operations in render** - `getDirSize()` uses `du -sh` which is slow
- **Sync exec for shell commands** - Uses `execSync` with timeouts
- **CONFIRM override** - Pass `CONFIRM=false` via `bash -c` wrapper

## File Locations

| File | Purpose |
|------|---------|
| `~/.config/shuttle/config` | SSD path, storage dir, confirm setting |
| `~/.config/shuttle/manifest.json` | Tracks all offloaded items |
| `~/bin/shuttle` | Symlink to CLI tool |
| `$SSD_PATH/Shuttle/` | Default storage location on SSD |

## Common Tasks

### Adding a new CLI command

1. Add `cmd_newcommand()` function
2. Add case in `main()` switch
3. Update help text in `cmd_help()`
4. Update completions in `completions/_shuttle`

### Adding a Raycast command

1. Create new `src/command.tsx`
2. Add entry in `package.json` commands array
3. Import utils as needed from `utils.ts`
4. Rebuild with `npm run build`

### Debugging Raycast extension

- Check Raycast developer console for errors
- Add `console.log()` statements
- Test utils functions directly with Node.js
- Use `npm run dev` for hot reload

## Known Issues & Solutions

### Raycast shows "loading forever"

- **Cause**: Slow `execSync` calls (e.g., `du -sh` on large dirs)
- **Solution**: Don't call `getDirSize()` during initial load, defer or skip

### Restore says success but doesn't work

- **Cause**: `CONFIRM` env var overwritten by config source
- **Solution**: Preserve env var before sourcing config (see `ensure_config()`)

### SSD not detected

- **Cause**: Config path doesn't match actual mount point
- **Solution**: Check `/Volumes/` and update `SSD_PATH` in config

## Testing

```bash
# Test CLI with confirmation disabled
CONFIRM=false shuttle offload ~/personal/test-dir
CONFIRM=false shuttle restore ~/personal/test-dir

# Test health check
shuttle health
shuttle health --quiet  # Returns exit code only

# Verify manifest
cat ~/.config/shuttle/manifest.json | jq

# Test Raycast extension
cd raycast-extension && npm run build
```

## Dependencies

### CLI
- Bash 4+
- `jq` (optional, for manifest operations)
- Standard macOS tools: `mv`, `ln`, `du`, `df`

### Raycast Extension
- Node.js 18+
- `@raycast/api`
- TypeScript

## Code Style

### CLI (Bash)
- Functions prefixed with `cmd_` for commands, others are utilities
- Use `log_info`, `log_success`, `log_error` for output
- Always quote variables: `"$var"`
- Use `[[ ]]` for conditionals

### Raycast (TypeScript)
- Functional React components
- State via `useState`, effects via `useEffect`
- Sync operations only (no async/await for shell commands)
- Error handling with try/catch, show toast on failure
