# Shuttle

Seamlessly move directories between internal and external drives on macOS.

## The Problem

You have a fast internal SSD with limited space and a large external SSD for extra storage. You want to:

- Move inactive projects to the external drive to free up space
- Bring them back instantly when you need to work on them
- Keep using the same paths without changing your workflow

## The Solution

Shuttle moves directories to your external SSD and leaves symlinks in their place. Your tools, scripts, and muscle memory all work exactly the same.

```
~/projects/my-app  →  shuttle offload  →  ~/projects/my-app (symlink → SSD)
~/projects/my-app  →  shuttle restore  →  ~/projects/my-app (local)
```

## Installation

### CLI

```bash
# Clone the repository
git clone https://github.com/duongdev/ssd-shuttle.git ~/.ssd-shuttle

# Create symlink to add shuttle to your PATH
mkdir -p ~/bin
ln -s ~/.ssd-shuttle/shuttle ~/bin/shuttle

# Add shell integration (completions + health check on startup)
echo 'source ~/.ssd-shuttle/shuttle-init.zsh' >> ~/.zshrc
```

### Raycast Extension

```bash
cd ~/.ssd-shuttle/raycast-extension
npm install
npm run dev
```

Then import the extension in Raycast: open Raycast → "Import Extension" → select the `raycast-extension` folder.

## CLI Usage

```bash
# Offload a directory to external SSD
shuttle offload ~/projects/old-project

# Check status of a directory
shuttle status ~/projects/old-project
# → State: Offloaded
# → Symlink → /Volumes/ExtSSD/Shuttle/projects/old-project

# Restore when you need fast local access
shuttle restore ~/projects/old-project

# List all offloaded items
shuttle list

# Health check - verify SSD connection and symlinks
shuttle health

# View configuration
shuttle config
```

### Commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `offload <path>` | `off`, `o` | Move to SSD, create symlink |
| `restore <path>` | `res`, `r` | Move back to internal drive |
| `status [path]` | `stat`, `s` | Show status of path or general status |
| `list` | `ls`, `l` | List all offloaded directories |
| `health` | `h` | Check SSD connection and symlinks |
| `config` | `conf`, `c` | Show configuration |

## Raycast Extension

The Raycast extension provides a GUI for shuttle operations.

### Commands

| Command | Description |
|---------|-------------|
| **Shuttle Status** | Main view showing all directories (offloaded + local) |
| **Offload Directory** | Browse and offload local directories |
| **Restore Directory** | Browse and restore offloaded directories |
| **Health Check** | Verify SSD connection and symlink integrity |

### Features

- View SSD free space at a glance
- See offloaded items with dates
- One-click offload/restore with confirmation
- Visual indicators for SSD connection status
- Keyboard shortcuts (`⌘+R` to refresh)

## Configuration

Configuration is stored at `~/.config/shuttle/config`:

```bash
# External SSD mount point
SSD_PATH="/Volumes/ExtSSD"

# Directory on SSD to store offloaded items
STORAGE_DIR="Shuttle"

# Require confirmation before operations (true/false)
CONFIRM=true
```

### Manifest

Offloaded items are tracked in `~/.config/shuttle/manifest.json`:

```json
{
  "items": [
    {
      "original": "/Users/you/projects/old-project",
      "offloaded": "/Volumes/ExtSSD/Shuttle/projects/old-project",
      "timestamp": "2024-01-15T10:30:00Z"
    }
  ]
}
```

## Shell Integration

The `shuttle-init.zsh` script provides:

1. **Tab completions** - `shuttle off<TAB>` → `shuttle offload`
2. **Health check on startup** - Warns if SSD is disconnected but you have offloaded items

```bash
# Add to ~/.zshrc
source ~/.ssd-shuttle/shuttle-init.zsh
```

## Requirements

- macOS
- External SSD formatted as **APFS** (recommended) or HFS+
  - exFAT works but has limitations with symlinks
- `jq` (optional, for better list formatting): `brew install jq`

## How It Works

1. **Offload**:
   - Moves the directory to `$SSD_PATH/$STORAGE_DIR/`, preserving the relative path from `$HOME`
   - Creates a symlink at the original location pointing to the SSD
   - Records the operation in the manifest

2. **Restore**:
   - Removes the symlink
   - Moves the data back from SSD to the original location
   - Removes the entry from the manifest
   - Cleans up empty parent directories on the SSD

3. **Symlink Transparency**:
   - All your tools see the same paths
   - Git, editors, build tools work normally
   - No need to update project configurations

## Tips

### Good Candidates for Offloading

- Old/inactive projects
- Large archives or backups
- iOS Simulator data (`~/Library/Developer/CoreSimulator`)
- Android SDK (`~/Library/Android`)
- Inactive node_modules (but consider deleting instead)

### Keep Local

- Active projects you're working on daily
- Frequently accessed files
- Anything where SSD latency matters

### SSD Format

For best results, format your external SSD as **APFS Encrypted**:

```bash
diskutil eraseDisk APFS "ExtSSD" GPT /dev/diskX
diskutil apfs encryptVolume "ExtSSD" -user disk
```

## Offloading System Directories

Development tools create large caches that are perfect for offloading. Here's how to handle each:

### iOS Simulators (10-50GB)

```bash
# Quit Xcode and Simulator first
killall Simulator 2>/dev/null; killall Xcode 2>/dev/null

# Offload via symlink
shuttle offload ~/Library/Developer/CoreSimulator
```

### npm Cache (5-20GB)

**Option A: Symlink**
```bash
shuttle offload ~/.npm
```

**Option B: Configure npm directly (recommended)**
```bash
mkdir -p /Volumes/ExtSSD/Caches/npm
npm config set cache /Volumes/ExtSSD/Caches/npm
```

### pnpm Store (2-10GB)

Configure pnpm to use external storage:
```bash
mkdir -p /Volumes/ExtSSD/Caches/pnpm
pnpm config set store-dir /Volumes/ExtSSD/Caches/pnpm
```

### Android SDK (5-15GB)

```bash
# Quit Android Studio first
shuttle offload ~/Library/Android
```

The `ANDROID_HOME` environment variable still works since it points to the symlink.

### Xcode DerivedData (Variable)

**Option A: Symlink**
```bash
# Quit Xcode first
shuttle offload ~/Library/Developer/Xcode/DerivedData
```

**Option B: Configure in Xcode (recommended)**
1. Open Xcode → Settings → Locations
2. Set "Derived Data" to Custom: `/Volumes/ExtSSD/Xcode/DerivedData`

### Docker Data (Variable)

Docker Desktop manages its own disk image. Configure via Docker settings:

1. Open Docker Desktop → Settings → Resources
2. Change "Disk image location" to `/Volumes/ExtSSD/Docker/Docker.raw`
3. Click "Apply & Restart"

### Quick Reference

| Directory | Typical Size | Method | Notes |
|-----------|--------------|--------|-------|
| `~/Library/Developer/CoreSimulator` | 10-50GB | Symlink | Quit Xcode first |
| `~/.npm` | 5-20GB | Config or Symlink | `npm config set cache` |
| pnpm store | 2-10GB | Config | `pnpm config set store-dir` |
| `~/Library/Android` | 5-15GB | Symlink | Quit Android Studio first |
| Xcode DerivedData | Variable | Config or Symlink | Xcode Settings preferred |
| Docker | Variable | Config | Docker Desktop Settings |

### Safety Notes

- **Always quit the app** before offloading its data directories
- **Caches are regeneratable** - if something breaks, delete and let it rebuild
- **Test after offloading** - open the app and verify it works normally
- **DerivedData is disposable** - can be deleted entirely; Xcode rebuilds as needed

## Project Structure

```
ssd-shuttle/
├── shuttle                 # Main CLI tool (bash)
├── shuttle-init.zsh        # Shell integration
├── completions/
│   ├── _shuttle            # Zsh completions
│   └── shuttle.bash        # Bash completions
├── raycast-extension/      # Raycast GUI
│   ├── src/
│   │   ├── index.tsx       # Main status view
│   │   ├── offload.tsx     # Offload command
│   │   ├── restore.tsx     # Restore command
│   │   └── health.tsx      # Health check
│   │   └── utils.ts        # Shared utilities
│   └── package.json
├── README.md
└── CLAUDE.md               # AI assistant context
```

## Troubleshooting

### "External SSD Not Connected"

- Check if the SSD is mounted: `ls /Volumes/`
- Verify the path in config matches: `shuttle config`
- Update `SSD_PATH` if the volume name changed

### Symlink Broken After Restore

The manifest may be out of sync. Check `~/.config/shuttle/manifest.json` and remove stale entries.

### Slow Performance

If operations are slow, check:
- SSD connection (USB-C is faster than USB-A)
- Large directories with many small files take longer to move

## License

MIT
