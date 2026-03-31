
[![Download Latest Release](https://img.shields.io/badge/Download-Latest%20Release-blue?style=for-the-badge&logo=github)](https://github.com/Cybersonics/Collaborative_Pathplanner_103_Fork/releases)

> **Note:** This executable is not signed, so Windows will show the "Protected your PC" message. Click on **"More Info"** and **"Run anyway"** and you should be off to the races.






# PathPlanner


## About



PathPlanner is a motion profile generator for FRC robots created by team 3015. The main features of PathPlanner include:
* Each path is made with Bézier curves, allowing fine tuning of the exact path shape.
* Holonomic mode supports decoupling the robot's rotation from its direction of travel.
* Real-time path preview
* Allows placing "event markers" along the path which can be used to trigger other code while path following.
* Build modular autonomous routines using other paths.
* Automatic saving and file management
* Robot-side vendor library for path generation and custom path following commands/controllers
* Full autonomous command generation with PathPlannerLib auto builder
* Real time path following telemetry
* Hot reload (paths and autos can be updated and regenerated on the robot without redeploying code)
* Automatic pathfinding in PathPlannerLib with AD*

## Usage and Documentation
### [pathplanner.dev](https://pathplanner.dev)

<br/>

Make sure you [install PathPlannerLib](https://pathplanner.dev/pplib-getting-started.html) to generate your paths.
```
https://3015rangerrobotics.github.io/pathplannerlib/PathplannerLib.json
```

[Java API Docs](https://pathplanner.dev/api/java/)

[C++ API Docs](https://pathplanner.dev/api/cpp/)

[Python API Docs](https://pathplanner.dev/api/python/)

## How to build manually:
* [Install Flutter](https://flutter.dev/docs/get-started/install)
* Open the project in a terminal and run the following command: `flutter build <PLATFORM>`
   * Valid platforms are:
      * windows
      * macos
      * linux
* The built app will be located here:
    * Windows: `<PROJECT DIR>/build/windows/runner/Release`
    * macOS: `<PROJECT DIR>/build/macos/Build/Products/Release`
    * Linux: `<PROJECT DIR>/build/linux/x64/release/bundle`
* OR `flutter run` to run in debug mode

---

## Ghost Auto Overlay System (Fork Addition)
![PathPlanner](https://github.com/Cybersonics/Collaborative_Pathplanner_103_Fork/blob/main/visual.gif)

This fork adds a **Ghost Auto Overlay System** that does not exist in the upstream [mjansen4857/pathplanner](https://github.com/mjansen4857/pathplanner) repository. It lets you visualize other robots' autonomous routines as translucent reference overlays while editing your own paths — useful for alliance coordination and avoiding on-field collisions.

### Features

1. **Ghost Auto Data Model** — A ghost auto captures a simulated trajectory plus the full robot config (bumper size, offset, swerve module locations, holonomic flag) and a team name label. Stored as `.ghostauto` JSON files.

2. **Import/Export** — Import individual `.ghostauto` files via file picker, or batch-import from another PathPlanner project folder. Batch-export all autos in your current project as ghosts to a chosen directory.

3. **Multi-Ghost Rendering** — Up to 10 simultaneous ghosts with distinct color-coded trajectories, robot outlines with swerve modules, and start/end indicators. Ghosts animate in sync with the main trajectory preview.

4. **Collision Detection** — Automatic time-sampled bounding-circle collision checks between the main trajectory and each ghost, and between ghost pairs. Collisions render as red warning circles on the field.

5. **LAN Sync (Real-Time Multi-Peer)** — Zero-configuration peer discovery via UDP broadcast. Deterministic WebSocket connections with automatic port fallback (5811–5821). Multiple PathPlanner instances on the same network see each other's current auto as a ghost in real-time. Includes keepalive, reconnect logic, backpressure, and graceful ghost fade on disconnect.

![Turning on LAN Search](https://github.com/user-attachments/assets/d3167205-aa40-4c7d-b957-81ba378ca2b9)


### Files Added or Modified

| File | What Changed |
|---|---|
| `lib/auto/ghost_auto.dart` | **New.** Ghost auto data model, serialization, import/export, trajectory sampling, 10-color palette. |
| `lib/services/ghost_sync_service.dart` | **New.** LAN sync service (~740 lines): UDP discovery, WebSocket data, multi-peer N:N topology, backpressure, identity re-keying, ghost fade timers. |
| `lib/main.dart` | Instantiates `GhostSyncService` at startup, restores sync preference. |
| `lib/util/prefs.dart` | Added ghost-related preference keys and defaults. |
| `lib/util/path_painter_util.dart` | Added optional `bumperStrokeWidth` parameter to `paintRobotOutline()`. |
| `lib/pages/home_page.dart` | Export/Import Ghosts toolbar actions; batch operations; wires sync service. |
| `lib/pages/auto_editor_page.dart` | Passes ghost data and sync service through to child editors. |
| `lib/widgets/editor/split_auto_editor.dart` | Manages local + network ghost state, visibility toggle, pin-on-disconnect, sync listeners. |
| `lib/widgets/editor/split_path_editor.dart` | Forwards ghost data to painter; renders color-coded ghost legend. |
| `lib/widgets/editor/path_painter.dart` | Renders ghost trajectories, ghost robots, endpoint indicators, collision warnings; visual polish. |
| `lib/widgets/editor/tree_widgets/auto_tree.dart` | Ghost legend sidebar with visibility/pin/remove controls; sync toggle panel with team # field. |

---

### How to Use the Ghost System

#### Exporting Ghosts (Sharing Your Autos)

1. Open your PathPlanner project that has one or more autos with simulated trajectories.
2. In the side hamburger menu toolbar, click **Export Ghosts**.
3. Choose a destination folder (e.g. a shared network drive, USB stick, or a folder inside an alliance partner's project).
4. All of your autos will be exported as `.ghostauto` files into that folder. Each file contains the trajectory, robot dimensions, and module locations.

#### Importing Ghosts (Loading Another Robot's Autos)

**From file picker:**
1. Open the auto you're editing in the auto editor.
2. On the toolbar, a download icon will say "Load Reference Auto" on hover.
3. Select a `.ghostauto` file. The ghost will appear on the field as a color-coded overlay.

**From another teams pathplanner project folder:**
1. From the codebase of the team you are gathering ghosts from, copy the "pathplanner" folder from within "\src\main\deploy" folder onto a usb stick for transfer.
2. In the side hamburger menu of pathplanner, click **Import Ghosts** below the settings button.
3. select the copied "pathplanner" folder, and enter a team name. The import tool will generate all the *.ghostauto files, which can then be used as references.

#### Managing Ghosts in the Editor

Once ghosts are loaded, the sidebar shows a **ghost legend** with each ghost's name, team label, and color. You can:

- **Toggle visibility** — Click the **eye icon** next to a ghost to hide/show it on the field without removing it.
- **Remove a ghost** — Click the **X icon** to remove a specific local ghost.
- **Clear all** — Click the **clear all** button to remove every ghost at once.
- **Pin a network ghost** — If a ghost came from LAN sync and the peer disconnects, click the **push-pin icon** to convert it into a local ghost so it stays.

#### Using LAN Sync (Real-Time)

LAN sync lets multiple PathPlanner instances on the same network automatically discover each other and share their current auto as a ghost — no file exchange needed.

1. **Enable sync** — In the auto editor sidebar, click the **sync toggle button** (antenna/broadcast icon). This starts UDP discovery on port 5810 and opens a WebSocket server on port 5811 (or the next available port up to 5821).
2. **Set your team number** — By holding the **sync toggle button** for 2 seconds, sync options will pop up. In the sync panel, enter your team number or display name. This is how peers identify you in their ghost legend. The name persists across sessions.
3. **Wait for peers** — As long as both instances are on the same LAN and have sync enabled, they will discover each other within a few seconds. The status indicator will change from "Searching..." to "Connected" and show the peer count.
4. **View peer ghosts** — Once connected, whatever auto each peer has open will appear as a ghost on your field (and vice versa). When either side switches autos, the ghost updates automatically.
5. **Manual connect** — If auto-discovery doesn't work (e.g. UDP broadcast is blocked), click the sync button's dropdown and choose **Manual Connect**. Enter the peer's IP address and port as `ip:port` (e.g. `192.168.1.42:5811`). You can find the peer's IP and port in their sync panel tooltip.

#### Collision Detection

When ghosts are loaded, PathPlanner automatically checks for collisions between your robot's trajectory and each ghost, and between ghost pairs. Collisions appear as **red warning circles with exclamation marks** drawn on the field at the location and time where two robots would overlap. This is based on bumper bounding-circle overlap sampled at 0.1-second intervals. Probably not a perfect representation, but it should work as a quick reference.

---

### LAN Sync Troubleshooting

| Problem | Likely Cause | Fix |
|---|---|---|
| Sync stays on "Searching..." forever | UDP broadcast (port 5810) is blocked by a firewall or network policy | Add a firewall exception for PathPlanner on **UDP 5810** and **TCP 5811–5821**. On Windows, the first time you enable sync you should see a Windows Firewall prompt — click "Allow". |
| Firewall prompt never appeared | PathPlanner was already allowed/blocked in a previous session, or a third-party firewall is intercepting | Open Windows Firewall > Allowed Apps (or your firewall's equivalent) and ensure PathPlanner is allowed on **Private** networks for both TCP and UDP. |
| Peers discover each other but never connect | WebSocket port (5811–5821) is blocked, or one side's port is in use by another application | Check that TCP ports 5811–5821 are open. If another app is using 5811, PathPlanner will try the next port automatically, but the peer needs to be able to reach it. |
| "Failed to connect" error on manual connect | Wrong IP or port, peer's sync is disabled, or a firewall is blocking the connection | Verify the target IP and port (shown in the peer's sync panel tooltip). Make sure the peer has sync **enabled** before you try to connect. |
| Ghost appears then disappears after ~3 seconds | The peer disconnected or switched to an auto with no trajectory; ghosts fade after 3 seconds by default | This is normal behavior. If you want to keep the ghost, click the **push-pin icon** before it fades to convert it to a local ghost. |
| Only works on one network but not another | Some networks (particularly school/enterprise Wi-Fi with client isolation) block traffic between devices | Use a **direct Ethernet connection** or a **simple switch/router** with no client isolation. A dumb switch between two laptops works perfectly. USB-to-Ethernet adapters are fine. |
| Works over Ethernet but not Wi-Fi | Wi-Fi access point has AP/client isolation enabled | Disable AP isolation in router settings, or connect both machines via Ethernet instead. |
| Both machines are on the same switch but nothing happens | Machines are on different subnets (e.g. one is 192.168.1.x, the other is 10.0.0.x) | Make sure both machines have IPs on the **same subnet**. Set static IPs if needed (e.g. both on 192.168.1.x with mask 255.255.255.0). |
| Sync works but ghosts stutter or lag | Large trajectory data with many states; network congestion; backpressure kicking in | This is rare — the system uses backpressure to skip redundant sends. If it persists, check for other heavy network traffic on the same link. |
| "Port already in use" error on enable | Another PathPlanner instance (or another app) is already bound to UDP 5810 on this machine | Close the other instance. If running two PathPlanner instances on the **same machine**, only one can bind UDP 5810 — use manual connect for the second instance. |
| Peer shows wrong team name | Peer changed their display name after connecting | The name updates automatically when the peer changes it. If it doesn't, toggling sync off and on will re-sync identities. |
| Ghost robot is the wrong size | The ghost was exported from a project with different robot dimensions | Ghost files store the exporting robot's bumper size and module locations. This is correct — it shows the *other* robot's real footprint. |

---

---

## Duplicate Auto with Paths

![duplicate with paths3](https://github.com/user-attachments/assets/dc96344e-cd62-4792-a547-70fbaf493a45)

When you duplicate an auto normally, the copy still references the same shared paths as the original. If you then edit those paths for the new auto, you'll break every other auto that uses them. **Duplicate with Paths** solves this by copying the auto *and* its paths together, so you can safely edit the copies without affecting anything else.

### Shared Path Warning

When you open a path for editing (either from the auto editor or the project browser) that is used by **2 or more autos**, a warning dialog appears:

- Lists every auto that references the path
- **Edit Anyway** — proceed to edit the shared original (all autos will be affected)
- **Duplicate & Edit** *(auto editor only)* — automatically creates a private copy of the path for your current auto and opens the copy for editing
- **Cancel** — go back without editing

### Using Duplicate with Paths

1. In the project browser, **right-click** (or open the context menu on) any auto card.
2. Select **Duplicate with Paths** (copy-all icon).
3. A wizard dialog appears with four sections:

| Section | What It Does |
|---|---|
| **Auto Name** | Pre-filled with "Copy of {name}". Edit to whatever you like. Validates against existing auto names. |
| **Path Selection** | Checkboxes for every path the auto references. Check the ones you want duplicated; unchecked paths will still be referenced by name (shared). |
| **Destination Folder** | Choose where duplicated paths are saved: *Same as original*, *No folder* (root), any existing folder, or *New folder* (creates a folder named after the new auto). |
| **Linked Waypoints** | If any checked paths have linked waypoints, choose whether to duplicate the links (new independent link IDs) or keep the originals (paths stay linked to the same shared waypoints). |

4. Click **Duplicate**. The new auto and its duplicated paths are created and saved immediately.
5. Open the new auto and edit its paths freely — the originals are untouched.

### When to Use What

| Scenario | Recommended Action |
|---|---|
| Creating a new auto that reuses most of an existing auto's paths but needs tweaks | **Duplicate with Paths** — check only the paths you plan to modify |
| Quick one-off edit to a shared path from within the auto editor | **Duplicate & Edit** from the shared path warning |
| Intentionally editing a path that multiple autos should share | **Edit Anyway** from the shared path warning |

## A note on AI usage

To be upfront, I (@Crumboe) worked with Github Copilot to reference, plan, and build changes for this fork. 
