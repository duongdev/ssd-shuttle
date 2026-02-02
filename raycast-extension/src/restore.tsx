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
import * as fs from "fs";
import {
  getManifest,
  getSsdStatus,
  getRelativePath,
  getBasename,
  restoreDirectory,
} from "./utils";

interface RestoreItem {
  original: string;
  offloaded: string;
  name: string;
  displayPath: string;
  isAccessible: boolean;
  offloadedDate: string;
}

export default function Command() {
  const [items, setItems] = useState<RestoreItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [ssdConnected, setSsdConnected] = useState(false);

  const loadOffloadedItems = () => {
    setIsLoading(true);

    try {
      const status = getSsdStatus();
      setSsdConnected(status.connected);

      const manifest = getManifest();

      const restoreItems: RestoreItem[] = manifest.items.map((item) => {
        const accessible = status.connected && fs.existsSync(item.offloaded);
        return {
          original: item.original,
          offloaded: item.offloaded,
          name: getBasename(item.original),
          displayPath: getRelativePath(item.original),
          isAccessible: accessible,
          offloadedDate: item.timestamp?.split("T")[0] || "Unknown",
        };
      });

      // Sort by date (most recent first)
      restoreItems.sort((a, b) =>
        b.offloadedDate.localeCompare(a.offloadedDate),
      );

      setItems(restoreItems);
    } catch (e) {
      console.error("Error loading offloaded items:", e);
    }

    setIsLoading(false);
  };

  useEffect(() => {
    loadOffloadedItems();
  }, []);

  const handleRestore = async (item: RestoreItem) => {
    if (!item.isAccessible) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Cannot Restore",
        message: "External SSD is not connected",
      });
      return;
    }

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

    const success = restoreDirectory(item.original);

    if (success) {
      toast.style = Toast.Style.Success;
      toast.title = "Restored";
      toast.message = `${item.name} is now on internal drive`;
      loadOffloadedItems();
    } else {
      toast.style = Toast.Style.Failure;
      toast.title = "Failed";
      toast.message = "Could not restore directory";
    }
  };

  if (items.length === 0 && !isLoading) {
    return (
      <List>
        <List.EmptyView
          icon={{ source: Icon.Checkmark, tintColor: Color.Green }}
          title="No Offloaded Directories"
          description="All your directories are on the internal drive"
        />
      </List>
    );
  }

  return (
    <List
      isLoading={isLoading}
      searchBarPlaceholder="Search offloaded directories..."
    >
      <List.Section
        title="Offloaded Directories"
        subtitle={ssdConnected ? "SSD Connected" : "⚠️ SSD Disconnected"}
      >
        {items.map((item) => (
          <List.Item
            key={item.original}
            title={item.name}
            subtitle={item.displayPath}
            icon={{
              source: Icon.HardDrive,
              tintColor: item.isAccessible ? Color.Blue : Color.Red,
            }}
            accessories={[
              { text: item.offloadedDate, icon: Icon.Calendar },
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
                {item.isAccessible && (
                  <Action.ShowInFinder path={item.original} />
                )}
                <Action.CopyToClipboard
                  title="Copy Path"
                  content={item.original}
                />
                <Action
                  title="Refresh"
                  icon={Icon.ArrowClockwise}
                  onAction={loadOffloadedItems}
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
