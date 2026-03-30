class DuplicateAutoOptions {
  final String newAutoName;
  final Set<String> pathsToDuplicate;
  final String? destinationFolder;
  final bool keepOriginalFolder;
  final bool createNewFolder;
  final bool duplicateLinkedWaypoints;

  const DuplicateAutoOptions({
    required this.newAutoName,
    required this.pathsToDuplicate,
    this.destinationFolder,
    this.keepOriginalFolder = true,
    this.createNewFolder = false,
    this.duplicateLinkedWaypoints = false,
  });
}
