import { ActionPanel, Action, List, Icon, Color } from "@raycast/api";
import { useState, useEffect } from "react";
import * as fs from "fs";
import {
  getManifest,
  getSsdStatus,
  getShuttleConfig,
  isSymlink,
  getRelativePath,
  getBasename,
} from "./utils";

interface HealthItem {
  type: "ssd" | "symlink" | "target" | "summary";
  status: "ok" | "warning" | "error";
  title: string;
  message: string;
  path?: string;
}

export default function Command() {
  const [items, setItems] = useState<HealthItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [overallStatus, setOverallStatus] = useState<
    "ok" | "warning" | "error"
  >("ok");

  const runHealthCheck = () => {
    setIsLoading(true);

    try {
      const healthItems: HealthItem[] = [];
      let hasError = false;
      let hasWarning = false;

      // Check SSD connection
      const ssdStatus = getSsdStatus();
      const config = getShuttleConfig();

      if (ssdStatus.connected) {
        healthItems.push({
          type: "ssd",
          status: "ok",
          title: "External SSD",
          message: `Connected at ${config.ssdPath} (${ssdStatus.available || "?"} free)`,
        });
      } else {
        healthItems.push({
          type: "ssd",
          status: "error",
          title: "External SSD",
          message: `Not connected at ${config.ssdPath}`,
        });
        hasError = true;
      }

      // Check manifest items
      const manifest = getManifest();

      if (manifest.items.length === 0) {
        healthItems.push({
          type: "summary",
          status: "ok",
          title: "Offloaded Items",
          message: "No items offloaded",
        });
      } else {
        let healthyItems = 0;

        for (const item of manifest.items) {
          if (!isSymlink(item.original)) {
            healthItems.push({
              type: "symlink",
              status: "warning",
              title: getBasename(item.original),
              message: "Symlink missing (may have been restored manually)",
              path: item.original,
            });
            hasWarning = true;
            continue;
          }

          if (!fs.existsSync(item.offloaded)) {
            healthItems.push({
              type: "target",
              status: "error",
              title: getBasename(item.original),
              message: ssdStatus.connected
                ? "Target missing on SSD"
                : "SSD not connected",
              path: item.original,
            });
            hasError = true;
            continue;
          }

          healthyItems++;
        }

        if (healthyItems > 0) {
          healthItems.unshift({
            type: "summary",
            status: "ok",
            title: "Healthy Items",
            message: `${healthyItems} offloaded item(s) accessible`,
          });
        }
      }

      setOverallStatus(hasError ? "error" : hasWarning ? "warning" : "ok");
      setItems(healthItems);
    } catch (e) {
      console.error("Health check error:", e);
    }

    setIsLoading(false);
  };

  useEffect(() => {
    runHealthCheck();
  }, []);

  const getStatusIcon = (status: "ok" | "warning" | "error") => {
    switch (status) {
      case "ok":
        return { source: Icon.CheckCircle, tintColor: Color.Green };
      case "warning":
        return { source: Icon.ExclamationMark, tintColor: Color.Yellow };
      case "error":
        return { source: Icon.XMarkCircle, tintColor: Color.Red };
    }
  };

  const getOverallTitle = () => {
    switch (overallStatus) {
      case "ok":
        return "✓ All Systems Healthy";
      case "warning":
        return "⚠ Some Warnings";
      case "error":
        return "✗ Issues Detected";
    }
  };

  return (
    <List isLoading={isLoading}>
      <List.Section title={getOverallTitle()}>
        {items.map((item, index) => (
          <List.Item
            key={`${item.type}-${index}`}
            title={item.title}
            subtitle={item.message}
            icon={getStatusIcon(item.status)}
            accessories={
              item.path
                ? [{ text: getRelativePath(item.path), icon: Icon.Link }]
                : []
            }
            actions={
              <ActionPanel>
                <Action
                  title="Refresh"
                  icon={Icon.ArrowClockwise}
                  onAction={runHealthCheck}
                  shortcut={{ modifiers: ["cmd"], key: "r" }}
                />
                {item.path && (
                  <>
                    <Action.ShowInFinder path={item.path} />
                    <Action.CopyToClipboard
                      title="Copy Path"
                      content={item.path}
                    />
                  </>
                )}
              </ActionPanel>
            }
          />
        ))}
      </List.Section>
    </List>
  );
}
