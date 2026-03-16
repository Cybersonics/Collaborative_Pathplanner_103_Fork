import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/commands/wait_command.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/kinematics.dart';

/// A segment in the simulated auto timeline.
sealed class SimSegment {}

class SimPathSegment extends SimSegment {
  final String pathName;
  SimPathSegment(this.pathName);
}

class SimWaitSegment extends SimSegment {
  final num waitSeconds;
  SimWaitSegment(this.waitSeconds);
}

class AutoSimulator {
  /// Walk the command tree of a [SequentialCommandGroup] and extract an ordered
  /// list of [SimSegment]s representing the sequential timeline. Only the
  /// top-level sequential ordering matters for the preview: commands inside
  /// parallel/race/deadline groups run concurrently with paths and don't add
  /// extra sequential time.
  static List<SimSegment> extractSimSegments(SequentialCommandGroup sequence) {
    List<SimSegment> segments = [];
    _extractFromCommands(sequence.commands, segments);
    return segments;
  }

  static void _extractFromCommands(
      List<Command> commands, List<SimSegment> segments) {
    for (Command cmd in commands) {
      if (cmd is PathCommand && cmd.pathName != null) {
        segments.add(SimPathSegment(cmd.pathName!));
      } else if (cmd is WaitCommand) {
        if (cmd.waitTime > 0) {
          segments.add(SimWaitSegment(cmd.waitTime));
        }
      } else if (cmd is SequentialCommandGroup) {
        // Recurse into nested sequential groups — their children are sequential
        _extractFromCommands(cmd.commands, segments);
      } else if (cmd is CommandGroup) {
        // Parallel/Race/Deadline: children run concurrently.
        _extractFromConcurrentGroup(cmd, segments);
      }
      // NamedCommands: unknown duration, treated as 0.
    }
  }

  /// Handle a concurrent group (parallel/race/deadline) that appears in a
  /// sequential context. If it contains path commands, extract them. Otherwise,
  /// estimate the group's duration from wait commands and emit a hold-position
  /// segment.
  static void _extractFromConcurrentGroup(
      CommandGroup group, List<SimSegment> segments) {
    // Check if the group contains any path commands
    List<String> pathNames = [];
    _collectPathNames(group.commands, pathNames);

    if (pathNames.isNotEmpty) {
      // Group runs paths concurrently — extract them as sequential segments
      for (String name in pathNames) {
        segments.add(SimPathSegment(name));
      }
    } else {
      // No paths — estimate the group's hold-position duration from waits
      num? duration = _estimateGroupDuration(group);
      if (duration != null && duration > 0) {
        segments.add(SimWaitSegment(duration));
      }
    }
  }

  /// Recursively collect all path names from a command list.
  static void _collectPathNames(List<Command> commands, List<String> names) {
    for (Command cmd in commands) {
      if (cmd is PathCommand && cmd.pathName != null) {
        names.add(cmd.pathName!);
      } else if (cmd is CommandGroup) {
        _collectPathNames(cmd.commands, names);
      }
    }
  }

  /// Estimate the duration of a concurrent group based on its children's
  /// known durations (wait commands and nested groups).
  static num? _estimateGroupDuration(CommandGroup group) {
    if (group is DeadlineCommandGroup && group.commands.isNotEmpty) {
      // Deadline group runs until its first child (the deadline) finishes
      return _estimateCommandDuration(group.commands.first);
    }

    // Estimate duration of each direct child
    List<num> childDurations = [];
    for (Command child in group.commands) {
      num? d = _estimateCommandDuration(child);
      if (d != null) childDurations.add(d);
    }

    if (childDurations.isEmpty) return null;

    if (group is RaceCommandGroup) {
      // Race: first to finish → minimum known duration
      return childDurations.reduce((a, b) => a < b ? a : b);
    } else if (group is ParallelCommandGroup) {
      // Parallel: all must finish → maximum known duration
      return childDurations.reduce((a, b) => a > b ? a : b);
    }
    return null;
  }

  /// Estimate the duration of a single command (for group duration calculations).
  /// Returns null for commands with unknown duration (PathCommand, NamedCommand).
  static num? _estimateCommandDuration(Command cmd) {
    if (cmd is WaitCommand) return cmd.waitTime > 0 ? cmd.waitTime : null;
    if (cmd is SequentialCommandGroup) {
      num total = 0;
      for (Command child in cmd.commands) {
        num? d = _estimateCommandDuration(child);
        if (d != null) total += d;
      }
      return total > 0 ? total : null;
    }
    if (cmd is CommandGroup) {
      return _estimateGroupDuration(cmd);
    }
    // PathCommand, NamedCommand: unknown duration
    return null;
  }

  /// Generate hold-position trajectory states for a wait period.
  static List<TrajectoryState> _generateHoldStates(
      Pose2d pose, num startTime, num duration) {
    TrajectoryState startState = TrajectoryState.pregen(
      startTime,
      const ChassisSpeeds(),
      pose,
    );
    TrajectoryState endState = TrajectoryState.pregen(
      startTime + duration,
      const ChassisSpeeds(),
      pose,
    );
    return [startState, endState];
  }

  /// Simulate an auto by walking its command sequence. Paths are simulated as
  /// trajectories; wait commands insert hold-position gaps.
  static PathPlannerTrajectory? simulateAuto(
      List<PathPlannerPath> paths, RobotConfig robotConfig,
      {SequentialCommandGroup? sequence}) {
    if (paths.isEmpty) return null;

    // If no command sequence provided, fall back to chaining paths directly
    if (sequence == null) {
      return _simulatePathsOnly(paths, robotConfig);
    }

    List<SimSegment> segments = extractSimSegments(sequence);

    // Build a lookup map from path name to PathPlannerPath
    Map<String, PathPlannerPath> pathMap = {
      for (PathPlannerPath p in paths) p.name: p,
    };

    List<TrajectoryState> allStates = [];
    Pose2d currentPose = Pose2d(
        paths[0].pathPoints[0].position, paths[0].idealStartingState.rotation);
    ChassisSpeeds currentSpeeds = const ChassisSpeeds();

    for (SimSegment seg in segments) {
      if (seg is SimPathSegment) {
        PathPlannerPath? p = pathMap[seg.pathName];
        if (p == null) continue;

        PathPlannerTrajectory simPath = PathPlannerTrajectory(
            path: p,
            startingSpeeds: currentSpeeds,
            startingRotation: currentPose.rotation,
            robotConfig: robotConfig);

        num startTime =
            allStates.isNotEmpty ? allStates.last.timeSeconds : 0;
        for (TrajectoryState s in simPath.states) {
          s.timeSeconds += startTime;
          allStates.add(s);
        }

        currentPose = Pose2d(
          allStates.last.pose.translation,
          allStates.last.pose.rotation,
        );
        currentSpeeds = allStates.last.fieldSpeeds;
      } else if (seg is SimWaitSegment) {
        num startTime =
            allStates.isNotEmpty ? allStates.last.timeSeconds : 0;
        List<TrajectoryState> holdStates =
            _generateHoldStates(currentPose, startTime, seg.waitSeconds);
        allStates.addAll(holdStates);
        currentSpeeds = const ChassisSpeeds();
      }
    }

    if (allStates.isEmpty) return null;
    return PathPlannerTrajectory.fromStates(allStates);
  }

  /// Original path-only simulation (no command tree awareness).
  static PathPlannerTrajectory? _simulatePathsOnly(
      List<PathPlannerPath> paths, RobotConfig robotConfig) {
    if (paths.isEmpty) return null;

    List<TrajectoryState> allStates = [];

    Pose2d startPose = Pose2d(
        paths[0].pathPoints[0].position, paths[0].idealStartingState.rotation);
    ChassisSpeeds startSpeeds = const ChassisSpeeds();

    for (PathPlannerPath p in paths) {
      PathPlannerTrajectory simPath = PathPlannerTrajectory(
          path: p,
          startingSpeeds: startSpeeds,
          startingRotation: startPose.rotation,
          robotConfig: robotConfig);

      num startTime = allStates.isNotEmpty ? allStates.last.timeSeconds : 0;
      for (TrajectoryState s in simPath.states) {
        s.timeSeconds += startTime;
        allStates.add(s);
      }

      startPose = Pose2d(
        allStates.last.pose.translation,
        allStates.last.pose.rotation,
      );
      startSpeeds = allStates.last.fieldSpeeds;
    }

    return PathPlannerTrajectory.fromStates(allStates);
  }
}
