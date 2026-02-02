# Finder Quick Actions for Shuttle

Right-click context menu integration for macOS Finder.

## Installation

```bash
cd ~/.ssd-shuttle/finder-actions
./install.sh
```

This copies the Quick Action workflows to `~/Library/Services/` where Finder discovers them.

## Usage

1. **Right-click** a folder or symlink in Finder
2. Select **Quick Actions** from the context menu
3. Choose:
   - **Shuttle - Offload to SSD** - Appears for regular folders; moves to external SSD
   - **Shuttle - Restore from SSD** - Appears for symlinks (offloaded folders); restores to internal drive

### Visual Feedback

- **Success**: Native macOS notification with details
- **Error**: Alert dialog explaining what went wrong

## Uninstallation

```bash
./uninstall.sh
```

Or manually delete from `~/Library/Services/`:
- `Shuttle - Offload to SSD.workflow`
- `Shuttle - Restore from SSD.workflow`

## Requirements

- macOS 10.14+ (Mojave or later)
- Shuttle CLI installed at `~/bin/shuttle`
- **Full Disk Access** for Finder (required to write to external SSD)

### Granting Full Disk Access

1. Open **System Settings** → **Privacy & Security** → **Full Disk Access**
2. Click **+** (unlock if needed)
3. Press `Cmd+Shift+G` and enter `/System/Library/CoreServices/Finder.app`
4. Add Finder and ensure it's enabled

## Troubleshooting

### Quick Actions not showing

1. Open **System Settings** → **Privacy & Security** → **Extensions**
2. Click **Finder Extensions** (or **Quick Actions**)
3. Ensure the Shuttle workflows are enabled

### "shuttle not found" error

Verify shuttle is installed:
```bash
ls -la ~/bin/shuttle
```

If not, create the symlink:
```bash
ln -s ~/.ssd-shuttle/shuttle ~/bin/shuttle
```

### Actions appear grayed out

- **Offload** only appears for regular folders (not symlinks)
- **Restore** only appears for symlinks (offloaded folders)

### "Operation not permitted" error

Finder needs Full Disk Access to write to the external SSD. See [Granting Full Disk Access](#granting-full-disk-access) above.

## How It Works

These are Automator Quick Action workflows (`.workflow` bundles) that:

1. Receive folder paths from Finder
2. Run a shell script that calls `shuttle offload` or `shuttle restore`
3. Show native macOS notifications for feedback
4. Handle errors gracefully with alert dialogs

The workflows use `CONFIRM=false` to skip confirmation prompts since Finder's right-click action serves as implicit confirmation.
