import {
  ActionPanel,
  Action,
  List,
  Icon,
  Color,
  showToast,
  Toast,
  confirmAlert,
} from "@raycast/api";
import { useState, useEffect } from "react";
import {
  getManifest,
  getSsdStatus,
  getRelativePath,
  getBasename,
  restoreDirectory,
  offloadDirectory,
  getRecentDirectories,
} from "./utils";
import * as fs from "fs";

interface DirectoryItem {
  path: string;
  name: string;
  displayPath: string;
  isOffloaded: boolean;
  isAccessible: boolean;
  offloadedDate?: string;
}

export default function Command() {
  const [items, setItems] = useState<DirectoryItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [ssdInfo, setSsdInfo] = useState("");

  const loadData = () => {
    setIsLoading(true);

    try {
      const status = getSsdStatus();
      setSsdInfo(
        status.connected
          ? `💾 ${status.available || "?"} free`
          : "⚠️ SSD Disconnected",
      );

      const manifest = getManifest();
      const directories: DirectoryItem[] = [];

      // Add offloaded items
      for (const item of manifest.items) {
        const accessible = status.connected && fs.existsSync(item.offloaded);
        directories.push({
          path: item.original,
          name: getBasename(item.original),
          displayPath: getRelativePath(item.original),
          isOffloaded: true,
          isAccessible: accessible,
          offloadedDate: item.timestamp?.split("T")[0],
        });
      }

      // Add local directories (no size calculation - too slow)
      const localDirs = getRecentDirectories();
      for (const dir of localDirs) {
        directories.push({
          path: dir,
          name: getBasename(dir),
          displayPath: getRelativePath(dir),
          isOffloaded: false,
          isAccessible: true,
        });
      }

      // Sort: offloaded first, then alphabetically
      directories.sort((a, b) => {
        if (a.isOffloaded !== b.isOffloaded) return a.isOffloaded ? -1 : 1;
        return a.name.localeCompare(b.name);
      });

      setItems(directories);
    } catch (e) {
      console.error("Load error:", e);
    }

    setIsLoading(false);
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleRestore = async (item: DirectoryItem) => {
    const confirmed = await confirmAlert({
      title: "Restore Directory",
      message: `Move "${item.name}" back to internal drive?`,
      primaryAction: { title: "Restore" },
    });

    if (!confirmed) return;

    const toast = await showToast({
      style: Toast.Style.Animated,
      title: "Restoring...",
      message: item.name,
    });

    const success = restoreDirectory(item.path);

    if (success) {
      toast.style = Toast.Style.Success;
      toast.title = "Restored";
      toast.message = `${item.name} is now on internal drive`;
      loadData();
    } else {
      toast.style = Toast.Style.Failure;
      toast.title = "Failed";
      toast.message = "Could not restore directory";
    }
  };

  const handleOffload = async (item: DirectoryItem) => {
    const confirmed = await confirmAlert({
      title: "Offload Directory",
      message: `Move "${item.name}" to external SSD?`,
      primaryAction: { title: "Offload" },
    });

    if (!confirmed) return;

    const toast = await showToast({
      style: Toast.Style.Animated,
      title: "Offloading...",
      message: item.name,
    });

    const success = offloadDirectory(item.path);

    if (success) {
      toast.style = Toast.Style.Success;
      toast.title = "Offloaded";
      toast.message = `${item.name} moved to SSD`;
      loadData();
    } else {
      toast.style = Toast.Style.Failure;
      toast.title = "Failed";
      toast.message = "Could not offload directory";
    }
  };

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search directories...">
      <List.Section title="Offloaded" subtitle={ssdInfo}>
        {items
          .filter((i) => i.isOffloaded)
          .map((item) => (
            <List.Item
              key={item.path}
              title={item.name}
              subtitle={item.displayPath}
              icon={{
                source: Icon.HardDrive,
                tintColor: item.isAccessible ? Color.Blue : Color.Red,
              }}
              accessories={[
                item.offloadedDate
                  ? { text: item.offloadedDate, icon: Icon.Calendar }
                  : {},
                {
                  icon: item.isAccessible
                    ? { source: Icon.CheckCircle, tintColor: Color.Green }
                    : { source: Icon.XMarkCircle, tintColor: Color.Red },
                },
              ]}
              actions={
                <ActionPanel>
                  <Action
                    title="Restore to Internal"
                    icon={Icon.Download}
                    onAction={() => handleRestore(item)}
                  />
                  <Action.ShowInFinder path={item.path} />
                  <Action.CopyToClipboard
                    title="Copy Path"
                    content={item.path}
                  />
                  <Action
                    title="Refresh"
                    icon={Icon.ArrowClockwise}
                    onAction={loadData}
                    shortcut={{ modifiers: ["cmd"], key: "r" }}
                  />
                </ActionPanel>
              }
            />
          ))}
      </List.Section>

      <List.Section title="Local Directories">
        {items
          .filter((i) => !i.isOffloaded)
          .map((item) => (
            <List.Item
              key={item.path}
              title={item.name}
              subtitle={item.displayPath}
              icon={{ source: Icon.Folder, tintColor: Color.Yellow }}
              actions={
                <ActionPanel>
                  <Action
                    title="Offload to Ssd"
                    icon={Icon.Upload}
                    onAction={() => handleOffload(item)}
                  />
                  <Action.ShowInFinder path={item.path} />
                  <Action.CopyToClipboard
                    title="Copy Path"
                    content={item.path}
                  />
                  <Action
                    title="Refresh"
                    icon={Icon.ArrowClockwise}
                    onAction={loadData}
                    shortcut={{ modifiers: ["cmd"], key: "r" }}
                  />
                </ActionPanel>
              }
            />
          ))}
      </List.Section>
    </List>
  );
}
