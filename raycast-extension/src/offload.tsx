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
  getRecentDirectories,
  getSsdStatus,
  getRelativePath,
  getBasename,
  offloadDirectory,
} from "./utils";

interface DirectoryItem {
  path: string;
  name: string;
  displayPath: string;
}

export default function Command() {
  const [items, setItems] = useState<DirectoryItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [ssdConnected, setSsdConnected] = useState(false);

  const loadDirectories = () => {
    setIsLoading(true);

    try {
      const status = getSsdStatus();
      setSsdConnected(status.connected);

      if (!status.connected) {
        setItems([]);
        setIsLoading(false);
        return;
      }

      const dirs = getRecentDirectories();
      const directoryItems: DirectoryItem[] = dirs.map((dir) => ({
        path: dir,
        name: getBasename(dir),
        displayPath: getRelativePath(dir),
      }));

      // Sort alphabetically
      directoryItems.sort((a, b) => a.name.localeCompare(b.name));

      setItems(directoryItems);
    } catch (e) {
      console.error("Error loading directories:", e);
    }

    setIsLoading(false);
  };

  useEffect(() => {
    loadDirectories();
  }, []);

  const handleOffload = async (item: DirectoryItem) => {
    const confirmed = await confirmAlert({
      title: "Offload Directory",
      message: `Move "${item.name}" to external SSD?`,
      primaryAction: { title: "Offload" },
    });

    if (!confirmed) return;

    const toast = await showToast({ style: Toast.Style.Animated, title: "Offloading...", message: item.name });

    const success = offloadDirectory(item.path);

    if (success) {
      toast.style = Toast.Style.Success;
      toast.title = "Offloaded";
      toast.message = `${item.name} moved to SSD`;
      loadDirectories();
    } else {
      toast.style = Toast.Style.Failure;
      toast.title = "Failed";
      toast.message = "Could not offload directory";
    }
  };

  if (!ssdConnected && !isLoading) {
    return (
      <List>
        <List.EmptyView
          icon={{ source: Icon.ExclamationMark, tintColor: Color.Red }}
          title="External SSD Not Connected"
          description="Connect your external SSD to offload directories"
        />
      </List>
    );
  }

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search directories to offload...">
      <List.Section title="Available Directories">
        {items.map((item) => (
          <List.Item
            key={item.path}
            title={item.name}
            subtitle={item.displayPath}
            icon={{ source: Icon.Folder, tintColor: Color.Yellow }}
            actions={
              <ActionPanel>
                <Action title="Offload to SSD" icon={Icon.Upload} onAction={() => handleOffload(item)} />
                <Action.ShowInFinder path={item.path} />
                <Action.CopyToClipboard title="Copy Path" content={item.path} />
                <Action title="Refresh" icon={Icon.ArrowClockwise} onAction={loadDirectories} shortcut={{ modifiers: ["cmd"], key: "r" }} />
              </ActionPanel>
            }
          />
        ))}
      </List.Section>
    </List>
  );
}
