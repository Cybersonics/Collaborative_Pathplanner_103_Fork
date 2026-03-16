import 'package:flutter/material.dart';
import 'package:pathplanner/auto/ghost_auto.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/services/ghost_sync_service.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/command_group_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/editor_settings_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/reset_odom_tree.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class AutoTree extends StatefulWidget {
  final PathPlannerAuto auto;
  final List<String> allPathNames;
  final SharedPreferences prefs;
  final ValueChanged<String?>? onPathHovered;
  final VoidCallback? onSideSwapped;
  final VoidCallback? onAutoChanged;
  final ChangeStack undoStack;
  final num? autoRuntime;
  final Function(String?)? onEditPathPressed;
  final VoidCallback? onRenderAuto;
  final VoidCallback? onExportGhostAuto;
  final VoidCallback? onImportGhostAuto;
  final void Function(int index)? onClearGhostAuto;
  final VoidCallback? onClearAllGhosts;
  final List<GhostAuto> ghostAutos;
  final Set<int> hiddenGhostIndices;
  final void Function(int index)? onToggleGhostVisibility;
  final void Function(int index)? onPinGhostAuto;
  final GhostSyncService? ghostSyncService;

  const AutoTree({
    super.key,
    required this.auto,
    required this.allPathNames,
    required this.prefs,
    this.onPathHovered,
    this.onSideSwapped,
    this.onAutoChanged,
    required this.undoStack,
    this.autoRuntime,
    this.onEditPathPressed,
    this.onRenderAuto,
    this.onExportGhostAuto,
    this.onImportGhostAuto,
    this.onClearGhostAuto,
    this.onClearAllGhosts,
    this.ghostAutos = const [],
    this.hiddenGhostIndices = const {},
    this.onToggleGhostVisibility,
    this.onPinGhostAuto,
    this.ghostSyncService,
  });

  @override
  State<AutoTree> createState() => _AutoTreeState();
}

class _AutoTreeState extends State<AutoTree> {
  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Simulated Auto Time: ~${(widget.autoRuntime ?? 0).toStringAsFixed(2)}s',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              Row(
                children: [
                  Tooltip(
                    message: 'Export Auto to Image',
                    waitDuration: const Duration(milliseconds: 500),
                    child: IconButton(
                      onPressed: widget.onRenderAuto,
                      icon: const Icon(Icons.ios_share),
                    ),
                  ),
                  Tooltip(
                    message: 'Export as Reference Auto',
                    waitDuration: const Duration(milliseconds: 500),
                    child: IconButton(
                      onPressed: widget.onExportGhostAuto,
                      icon: const Icon(Icons.upload_file),
                    ),
                  ),
                  Tooltip(
                    message: widget.ghostAutos.length >= 2
                        ? 'Max 2 ghosts loaded'
                        : 'Load Reference Auto',
                    waitDuration: const Duration(milliseconds: 500),
                    child: IconButton(
                      onPressed: widget.onImportGhostAuto,
                      icon: Icon(
                        Icons.download,
                        color: widget.ghostAutos.isNotEmpty
                            ? GhostAuto.ghostColors[0]
                            : null,
                      ),
                    ),
                  ),
                  if (widget.ghostAutos.isNotEmpty)
                    Tooltip(
                      message: 'Clear All Reference Autos',
                      waitDuration: const Duration(milliseconds: 500),
                      child: IconButton(
                        onPressed: widget.onClearAllGhosts,
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ),
                  if (widget.ghostSyncService != null)
                    _GhostSyncToggle(
                        service: widget.ghostSyncService!,
                        prefs: widget.prefs),
                  Tooltip(
                    message: 'Move to Other Side',
                    waitDuration: const Duration(seconds: 1),
                    child: IconButton(
                      onPressed: widget.onSideSwapped,
                      icon: const Icon(Icons.swap_horiz),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4.0),
        // Ghost legend in the tree panel
        if (widget.ghostAutos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < widget.ghostAutos.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Icon(
                          widget.ghostAutos[i].isNetworkGhost
                              ? Icons.wifi
                              : Icons.visibility,
                          size: 16,
                          color: GhostAuto.ghostColors[
                              i % GhostAuto.ghostColors.length],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.ghostAutos[i].displayLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: GhostAuto.ghostColors[
                                  i % GhostAuto.ghostColors.length],
                              fontStyle: FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Visibility toggle
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            onPressed: () =>
                                widget.onToggleGhostVisibility?.call(i),
                            icon: Icon(
                              widget.hiddenGhostIndices.contains(i)
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 16,
                              color: GhostAuto.ghostColors[
                                  i % GhostAuto.ghostColors.length],
                            ),
                            tooltip: widget.hiddenGhostIndices.contains(i)
                                ? 'Show'
                                : 'Hide',
                          ),
                        ),
                        // Pin network ghost as local
                        if (widget.ghostAutos[i].isNetworkGhost)
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              onPressed: () =>
                                  widget.onPinGhostAuto?.call(i),
                              icon: Icon(Icons.push_pin,
                                  size: 16,
                                  color: GhostAuto.ghostColors[
                                      i % GhostAuto.ghostColors.length]),
                              tooltip: 'Pin (keep after disconnect)',
                            ),
                          ),
                        // Remove local ghost
                        if (!widget.ghostAutos[i].isNetworkGhost)
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              onPressed: () =>
                                  widget.onClearGhostAuto?.call(i),
                              icon: Icon(Icons.close,
                                  size: 16,
                                  color: GhostAuto.ghostColors[
                                      i % GhostAuto.ghostColors.length]),
                              tooltip: 'Remove',
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Card(
                  elevation: 1.0,
                  color: colorScheme.surface,
                  surfaceTintColor: colorScheme.surfaceTint,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CommandGroupWidget(
                      command: widget.auto.sequence,
                      allPathNames: widget.allPathNames,
                      onPathCommandHovered: widget.onPathHovered,
                      onUpdated: widget.onAutoChanged,
                      undoStack: widget.undoStack,
                      showEditPathButton: !widget.auto.choreoAuto,
                      onEditPathPressed: widget.onEditPathPressed,
                    ),
                  ),
                ),
                ResetOdomTree(
                  auto: widget.auto,
                  onAutoChanged: widget.onAutoChanged,
                  undoStack: widget.undoStack,
                ),
                const Divider(),
                const EditorSettingsTree(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A toolbar button that toggles ghost sync on/off and shows connection state.
class _GhostSyncToggle extends StatefulWidget {
  final GhostSyncService service;
  final SharedPreferences prefs;

  const _GhostSyncToggle({required this.service, required this.prefs});

  @override
  State<_GhostSyncToggle> createState() => _GhostSyncToggleState();
}

class _GhostSyncToggleState extends State<_GhostSyncToggle> {
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onSyncChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.service.state;
    final IconData icon;
    final Color? color;
    final String tooltip;

    switch (state) {
      case GhostSyncState.disabled:
        icon = Icons.wifi_off;
        color = null;
        tooltip = 'Enable LAN Ghost Sync';
        break;
      case GhostSyncState.searching:
        icon = Icons.wifi_find;
        color = Colors.amber;
        tooltip = 'Searching for peers… (long-press for options)'
            '${widget.service.localIp != null ? '\nMy IP: ${widget.service.localIp}:${widget.service.wsPort}' : ''}';
        break;
      case GhostSyncState.connected:
        icon = Icons.wifi;
        color = Colors.greenAccent;
        final peerCount = widget.service.connectedPeerCount;
        final peerNames = widget.service.connectedPeers.values
            .map((p) => p.name.isEmpty ? 'peer' : p.name)
            .join(', ');
        tooltip =
            'Connected to $peerCount peer${peerCount != 1 ? 's' : ''}: $peerNames (long-press for options)'
            '${widget.service.localIp != null ? '\nMy IP: ${widget.service.localIp}:${widget.service.wsPort}' : ''}';
        break;
    }

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: IconButton(
        onPressed: () {
          if (state == GhostSyncState.disabled) {
            widget.service.enable();
            widget.prefs.setBool(PrefsKeys.ghostSyncEnabled, true);
          } else {
            widget.service.disable();
            widget.prefs.setBool(PrefsKeys.ghostSyncEnabled, false);
          }
        },
        onLongPress: state != GhostSyncState.disabled
            ? () => _showSyncPanel(context)
            : null,
        icon: Icon(icon, color: color),
      ),
    );
  }

  void _showSyncPanel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ipController = TextEditingController();
    final teamController = TextEditingController(
      text: widget.service.displayName,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          title: const Text('Ghost LAN Sync'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team # field
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Text('Team #:', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: teamController,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'e.g. 3015',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (value) {
                            widget.service.setDisplayName(value.trim());
                            widget.prefs.setString(
                                PrefsKeys.ghostSyncDisplayName, value.trim());
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.service.localIp != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16),
                        const SizedBox(width: 8),
                        Text('My address: ${widget.service.localIp}:${widget.service.wsPort}',
                            style: const TextStyle(
                                fontSize: 14, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                if (widget.service.lastError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      widget.service.lastError!,
                      style: TextStyle(color: colorScheme.error, fontSize: 13),
                    ),
                  ),
                const Text('Manual connect (if auto-discovery fails):',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ipController,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '10.0.0.x or 127.0.0.1:5812',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        String input = ipController.text.trim();
                        if (input.isNotEmpty) {
                          // Support ip:port syntax
                          String ip = input;
                          int? port;
                          if (input.contains(':')) {
                            final parts = input.split(':');
                            ip = parts[0];
                            port = int.tryParse(parts[1]);
                          }
                          widget.service.connectToAddress(ip, port: port);
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Connect'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
