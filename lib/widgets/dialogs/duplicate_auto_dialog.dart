import 'package:flutter/material.dart';
import 'package:pathplanner/auto/duplicate_auto_options.dart';
import 'package:pathplanner/path/pathplanner_path.dart';

class DuplicateAutoDialog extends StatefulWidget {
  final String autoName;
  final List<String> referencedPathNames;
  final List<String> pathFolders;
  final Set<String> existingAutoNames;
  final Set<String> existingPathNames;
  final List<PathPlannerPath> allPaths;

  const DuplicateAutoDialog({
    super.key,
    required this.autoName,
    required this.referencedPathNames,
    required this.pathFolders,
    required this.existingAutoNames,
    required this.existingPathNames,
    required this.allPaths,
  });

  @override
  State<DuplicateAutoDialog> createState() => _DuplicateAutoDialogState();
}

class _DuplicateAutoDialogState extends State<DuplicateAutoDialog> {
  late final TextEditingController _nameController;
  late final Map<String, bool> _pathChecks;
  String _folderSelection = _sameAsOriginal;
  bool _duplicateLinkedWaypoints = false;

  static const String _sameAsOriginal = '__same_as_original__';
  static const String _noFolder = '__no_folder__';
  static const String _newFolder = '__new_folder__';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Copy of ${widget.autoName}');
    _pathChecks = {
      for (final name in widget.referencedPathNames) name: true,
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _hasLinkedWaypoints {
    for (final pathName in _pathChecks.entries
        .where((e) => e.value)
        .map((e) => e.key)) {
      final path =
          widget.allPaths.where((p) => p.name == pathName).firstOrNull;
      if (path != null) {
        for (final waypoint in path.waypoints) {
          if (waypoint.linkedName != null) return true;
        }
      }
    }
    return false;
  }

  bool get _isNameValid {
    final name = _nameController.text.trim();
    return name.isNotEmpty && !widget.existingAutoNames.contains(name);
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    final hasLinked = _hasLinkedWaypoints;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      title: const Text('Duplicate Auto with Paths'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Auto Name
              Text('Auto Name',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  errorText: _nameController.text.trim().isEmpty
                      ? 'Name cannot be empty'
                      : widget.existingAutoNames
                              .contains(_nameController.text.trim())
                          ? 'An auto with this name already exists'
                          : null,
                ),
              ),
              const SizedBox(height: 20),

              // Section 2: Path Selection
              Text('Paths to Duplicate',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Unchecked paths will remain as shared references.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              if (widget.referencedPathNames.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'This auto has no path references.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              else
                ...widget.referencedPathNames.map((pathName) {
                  return CheckboxListTile(
                    title: Text(pathName),
                    value: _pathChecks[pathName] ?? false,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setState(() {
                        _pathChecks[pathName] = value ?? false;
                      });
                    },
                  );
                }),
              const SizedBox(height: 20),

              // Section 3: Destination Folder
              Text('Destination Folder for Duplicated Paths',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _folderSelection,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: _sameAsOriginal,
                    child: Text('(Same as original)'),
                  ),
                  const DropdownMenuItem(
                    value: _noFolder,
                    child: Text('(No folder)'),
                  ),
                  DropdownMenuItem(
                    value: _newFolder,
                    child: Row(
                      children: [
                        const Icon(Icons.create_new_folder, size: 18),
                        const SizedBox(width: 8),
                        Text(
                            'New folder: ${_nameController.text.trim().isEmpty ? "(enter auto name)" : _nameController.text.trim()}'),
                      ],
                    ),
                  ),
                  ...widget.pathFolders.map((folder) {
                    return DropdownMenuItem(
                      value: folder,
                      child: Text(folder),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _folderSelection = value ?? _sameAsOriginal;
                  });
                },
              ),

              // Section 4: Linked Waypoint Handling
              if (hasLinked) ...[
                const SizedBox(height: 20),
                Text('Linked Waypoints',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Choose whether duplicated paths should share linked waypoints with originals or get independent copies.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                RadioGroup<bool>(
                  groupValue: _duplicateLinkedWaypoints,
                  onChanged: (value) {
                    setState(() {
                      _duplicateLinkedWaypoints = value ?? false;
                    });
                  },
                  child: const Column(
                    children: [
                      RadioListTile<bool>(
                        title: Text('Keep original linked names'),
                        subtitle:
                            Text('Positions stay synced with originals'),
                        value: false,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<bool>(
                        title: Text('Duplicate linked names'),
                        subtitle: Text(
                            'Unlink from originals, keep internal links'),
                        value: true,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isNameValid
              ? () {
                  final checkedPaths = _pathChecks.entries
                      .where((e) => e.value)
                      .map((e) => e.key)
                      .toSet();

                  final isNewFolder = _folderSelection == _newFolder;
                  final folderName = isNewFolder
                      ? _nameController.text.trim()
                      : (_folderSelection == _sameAsOriginal ||
                              _folderSelection == _noFolder
                          ? null
                          : _folderSelection);

                  Navigator.of(context).pop(DuplicateAutoOptions(
                    newAutoName: _nameController.text.trim(),
                    pathsToDuplicate: checkedPaths,
                    destinationFolder: folderName,
                    keepOriginalFolder: _folderSelection == _sameAsOriginal,
                    createNewFolder: isNewFolder,
                    duplicateLinkedWaypoints: _duplicateLinkedWaypoints,
                  ));
                }
              : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
