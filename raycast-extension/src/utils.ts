import { execSync } from "child_process";
import * as fs from "fs";
import * as path from "path";

const HOME = process.env.HOME || "";
const CONFIG_DIR = path.join(HOME, ".config", "shuttle");
const CONFIG_FILE = path.join(CONFIG_DIR, "config");
const MANIFEST_FILE = path.join(CONFIG_DIR, "manifest.json");
const SHUTTLE_BIN = path.join(HOME, "bin", "shuttle");

export interface ShuttleConfig {
  ssdPath: string;
  storageDir: string;
  confirm: boolean;
}

export interface OffloadedItem {
  original: string;
  offloaded: string;
  timestamp: string;
}

export interface Manifest {
  items: OffloadedItem[];
}

export interface SsdStatus {
  connected: boolean;
  path: string;
  used?: string;
  available?: string;
  total?: string;
}

export function getShuttleConfig(): ShuttleConfig {
  const config: ShuttleConfig = {
    ssdPath: "/Volumes/ExtSSD",
    storageDir: "Shuttle",
    confirm: true,
  };

  try {
    if (!fs.existsSync(CONFIG_FILE)) {
      return config;
    }

    const content = fs.readFileSync(CONFIG_FILE, "utf-8");
    const lines = content.split("\n");

    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.startsWith("#") || !trimmed.includes("=")) continue;

      const eqIndex = trimmed.indexOf("=");
      const key = trimmed.slice(0, eqIndex).trim();
      let value = trimmed.slice(eqIndex + 1).trim();

      // Remove surrounding quotes
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1);
      }

      switch (key) {
        case "SSD_PATH":
          config.ssdPath = value.replace(/\/+$/, "");
          break;
        case "STORAGE_DIR":
          config.storageDir = value;
          break;
        case "CONFIRM":
          config.confirm = value.toLowerCase() === "true";
          break;
      }
    }
  } catch (e) {
    console.error("Error reading config:", e);
  }

  return config;
}

export function getManifest(): Manifest {
  try {
    if (!fs.existsSync(MANIFEST_FILE)) {
      return { items: [] };
    }
    const content = fs.readFileSync(MANIFEST_FILE, "utf-8");
    return JSON.parse(content);
  } catch {
    return { items: [] };
  }
}

export function getSsdStatus(): SsdStatus {
  const config = getShuttleConfig();

  const status: SsdStatus = {
    connected: false,
    path: config.ssdPath,
  };

  try {
    status.connected =
      fs.existsSync(config.ssdPath) &&
      fs.statSync(config.ssdPath).isDirectory();

    if (status.connected) {
      try {
        const df = execSync(`df -h "${config.ssdPath}" 2>/dev/null | tail -1`, {
          encoding: "utf-8",
          timeout: 3000,
        });
        const parts = df.trim().split(/\s+/);
        if (parts.length >= 4) {
          status.total = parts[1];
          status.used = parts[2];
          status.available = parts[3];
        }
      } catch {
        // Ignore df errors
      }
    }
  } catch {
    status.connected = false;
  }

  return status;
}

export function getStoragePath(): string {
  const config = getShuttleConfig();
  return path.join(config.ssdPath, config.storageDir);
}

export function isSymlink(filePath: string): boolean {
  try {
    return fs.lstatSync(filePath).isSymbolicLink();
  } catch {
    return false;
  }
}

export function getSymlinkTarget(filePath: string): string | null {
  try {
    return fs.readlinkSync(filePath);
  } catch {
    return null;
  }
}

export function isOffloaded(filePath: string): boolean {
  if (!isSymlink(filePath)) return false;
  const target = getSymlinkTarget(filePath);
  if (!target) return false;
  return target.startsWith(getStoragePath());
}

// This is slow - only call when needed, not during list loading
export function getDirSize(dirPath: string): string {
  try {
    const result = execSync(`du -sh "${dirPath}" 2>/dev/null | cut -f1`, {
      encoding: "utf-8",
      timeout: 5000,
    });
    return result.trim() || "?";
  } catch {
    return "?";
  }
}

export function getBasename(filePath: string): string {
  return path.basename(filePath);
}

export function getRelativePath(filePath: string): string {
  if (filePath.startsWith(HOME)) {
    return "~" + filePath.slice(HOME.length);
  }
  return filePath;
}

export function offloadDirectory(dirPath: string): boolean {
  try {
    // Use bash -c to properly set environment and run command
    const result = execSync(
      `bash -c 'CONFIRM=false "${SHUTTLE_BIN}" offload "${dirPath}"'`,
      {
        encoding: "utf-8",
        timeout: 120000,
        stdio: ["pipe", "pipe", "pipe"],
      },
    );
    console.log("Offload result:", result);
    return true;
  } catch (e: unknown) {
    const error = e as Error & { stderr?: string };
    console.error("Offload error:", error.message, error.stderr);
    return false;
  }
}

export function restoreDirectory(symlinkPath: string): boolean {
  try {
    // Use bash -c to properly set environment and run command
    const result = execSync(
      `bash -c 'CONFIRM=false "${SHUTTLE_BIN}" restore "${symlinkPath}"'`,
      {
        encoding: "utf-8",
        timeout: 120000,
        stdio: ["pipe", "pipe", "pipe"],
      },
    );
    console.log("Restore result:", result);
    return true;
  } catch (e: unknown) {
    const error = e as Error & { stderr?: string };
    console.error("Restore error:", error.message, error.stderr);
    return false;
  }
}

export function getRecentDirectories(): string[] {
  // Common development directory locations - customize as needed
  const locations = [
    path.join(HOME, "projects"),
    path.join(HOME, "dev"),
    path.join(HOME, "code"),
    path.join(HOME, "src"),
    path.join(HOME, "work"),
    path.join(HOME, "personal"),
  ];

  const dirs: string[] = [];

  for (const loc of locations) {
    try {
      if (!fs.existsSync(loc)) continue;

      const entries = fs.readdirSync(loc, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = path.join(loc, entry.name);

        // Skip hidden directories
        if (entry.name.startsWith(".")) continue;

        // Skip if already offloaded (is a symlink pointing to storage)
        if (isOffloaded(fullPath)) continue;

        // Only include actual directories (not symlinks to elsewhere)
        if (entry.isDirectory()) {
          dirs.push(fullPath);
        }
      }
    } catch {
      // Ignore errors for individual locations
    }
  }

  return dirs;
}
