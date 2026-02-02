/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `index` command */
  export type Index = ExtensionPreferences & {}
  /** Preferences accessible in the `offload` command */
  export type Offload = ExtensionPreferences & {}
  /** Preferences accessible in the `restore` command */
  export type Restore = ExtensionPreferences & {}
  /** Preferences accessible in the `health` command */
  export type Health = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `index` command */
  export type Index = {}
  /** Arguments passed to the `offload` command */
  export type Offload = {}
  /** Arguments passed to the `restore` command */
  export type Restore = {}
  /** Arguments passed to the `health` command */
  export type Health = {}
}

