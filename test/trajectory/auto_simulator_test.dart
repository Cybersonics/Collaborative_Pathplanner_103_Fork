import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/commands/wait_command.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/ideal_starting_state.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/point_towards_zone.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/trajectory/auto_simulator.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/trajectory/dc_motor.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

void main() {
  test('simulate auto', () {
    PathPlannerPath test = PathPlannerPath(
      name: '',
      waypoints: [
        Waypoint(
          anchor: const Translation2d(1, 1),
          nextControl: const Translation2d(3, 1),
        ),
        Waypoint(
          prevControl: const Translation2d(4, 3),
          anchor: const Translation2d(6, 3),
        ),
      ],
      globalConstraints: PathConstraints(),
      goalEndState: GoalEndState(0.0, const Rotation2d()),
      constraintZones: [
        ConstraintsZone(
            constraints: PathConstraints(),
            minWaypointRelativePos: 0.2,
            maxWaypointRelativePos: 0.4),
      ],
      pointTowardsZones: [PointTowardsZone()],
      rotationTargets: [
        RotationTarget(0.5, Rotation2d.fromDegrees(45)),
      ],
      eventMarkers: [],
      pathDir: '',
      fs: MemoryFileSystem(),
      reversed: false,
      folder: null,
      idealStartingState: IdealStartingState(0.0, const Rotation2d()),
      useDefaultConstraints: false,
    );

    PathPlannerPath test2 = PathPlannerPath(
      name: '',
      waypoints: [
        Waypoint(
          anchor: const Translation2d(7, 3),
          nextControl: const Translation2d(9, 3),
        ),
        Waypoint(
          prevControl: const Translation2d(10, 5),
          anchor: const Translation2d(12, 5),
        ),
      ],
      globalConstraints: PathConstraints(),
      goalEndState: GoalEndState(0.0, const Rotation2d()),
      constraintZones: [
        ConstraintsZone(
            constraints: PathConstraints(),
            minWaypointRelativePos: 0.2,
            maxWaypointRelativePos: 0.4),
      ],
      pointTowardsZones: [PointTowardsZone()],
      rotationTargets: [
        RotationTarget(0.5, Rotation2d.fromDegrees(45)),
      ],
      eventMarkers: [],
      pathDir: '',
      fs: MemoryFileSystem(),
      reversed: false,
      folder: null,
      idealStartingState: IdealStartingState(0.0, const Rotation2d()),
      useDefaultConstraints: false,
    );

    var config = RobotConfig(
      massKG: 70.0,
      moi: 6.8,
      moduleConfig: ModuleConfig(
        wheelRadiusMeters: 0.048,
        driveMotor: DCMotor.getKrakenX60(1).withReduction(5.12),
        driveCurrentLimit: 60,
        maxDriveVelocityMPS: 5.4,
        wheelCOF: 1.2,
      ),
      moduleLocations: const [
        Translation2d(0.25, 0.25),
        Translation2d(0.25, -0.25),
        Translation2d(-0.25, 0.25),
        Translation2d(-0.25, -0.25),
      ],
      holonomic: true,
      bumperSize: const Size(0.9, 0.9),
      bumperOffset: const Translation2d(),
    );

    // Basic coverage tests, expand in future
    PathPlannerTrajectory? sim = AutoSimulator.simulateAuto([], config);
    expect(sim, isNull);

    sim = AutoSimulator.simulateAuto([test], config);
    expect(sim, isNotNull);
    expect(sim!.states.last.timeSeconds, closeTo(3.82, 0.05));

    sim = AutoSimulator.simulateAuto([test2], config);
    expect(sim, isNotNull);
    expect(sim!.states.last.timeSeconds, closeTo(4.43, 0.05));

    sim = AutoSimulator.simulateAuto([test, test2], config);
    expect(sim, isNotNull);
    expect(sim!.states.last.timeSeconds, closeTo(8.25, 0.05));
  });

  group('extractSimSegments', () {
    test('empty sequence returns empty list', () {
      var seq = SequentialCommandGroup(commands: []);
      var segments = AutoSimulator.extractSimSegments(seq);
      expect(segments, isEmpty);
    });

    test('extracts path and wait segments in order', () {
      var seq = SequentialCommandGroup(commands: [
        PathCommand(pathName: 'path1'),
        WaitCommand(waitTime: 1.5),
        PathCommand(pathName: 'path2'),
      ]);
      var segments = AutoSimulator.extractSimSegments(seq);
      expect(segments.length, 3);
      expect(segments[0], isA<SimPathSegment>());
      expect((segments[0] as SimPathSegment).pathName, 'path1');
      expect(segments[1], isA<SimWaitSegment>());
      expect((segments[1] as SimWaitSegment).waitSeconds, 1.5);
      expect(segments[2], isA<SimPathSegment>());
      expect((segments[2] as SimPathSegment).pathName, 'path2');
    });

    test('skips named commands', () {
      var seq = SequentialCommandGroup(commands: [
        PathCommand(pathName: 'path1'),
        NamedCommand(name: 'someEvent'),
        PathCommand(pathName: 'path2'),
      ]);
      var segments = AutoSimulator.extractSimSegments(seq);
      expect(segments.length, 2);
      expect((segments[0] as SimPathSegment).pathName, 'path1');
      expect((segments[1] as SimPathSegment).pathName, 'path2');
    });

    test('recurses into nested sequential groups', () {
      var seq = SequentialCommandGroup(commands: [
        PathCommand(pathName: 'path1'),
        SequentialCommandGroup(commands: [
          WaitCommand(waitTime: 2.0),
          PathCommand(pathName: 'path2'),
        ]),
      ]);
      var segments = AutoSimulator.extractSimSegments(seq);
      expect(segments.length, 3);
      expect((segments[0] as SimPathSegment).pathName, 'path1');
      expect((segments[1] as SimWaitSegment).waitSeconds, 2.0);
      expect((segments[2] as SimPathSegment).pathName, 'path2');
    });

    test('estimates wait duration from race group', () {
      var seq = SequentialCommandGroup(commands: [
        PathCommand(pathName: 'path1'),
        RaceCommandGroup(commands: [
          WaitCommand(waitTime: 2.0),
          NamedCommand(name: 'waitForIntake'),
        ]),
        PathCommand(pathName: 'path2'),
      ]);
      var segments = AutoSimulator.extractSimSegments(seq);
      // Race group with wait + named → emits wait (min known duration)
      expect(segments.length, 3);
      expect((segments[0] as SimPathSegment).pathName, 'path1');
      expect(segments[1], isA<SimWaitSegment>());
      expect((segments[1] as SimWaitSegment).waitSeconds, 2.0);
      expect((segments[2] as SimPathSegment).pathName, 'path2');
    });

    test('estimates wait duration from parallel group', () {
      var seq = SequentialCommandGroup(commands: [
        PathCommand(pathName: 'path1'),
        ParallelCommandGroup(commands: [
          WaitCommand(waitTime: 3.0),
          NamedCommand(name: 'action'),
        ]),
        PathCommand(pathName: 'path2'),
      ]);
      var segments = AutoSimulator.extractSimSegments(seq);
      // Parallel group: all must finish → max known duration = 3.0
      expect(segments.length, 3);
      expect((segments[0] as SimPathSegment).pathName, 'path1');
      expect(segments[1], isA<SimWaitSegment>());
      expect((segments[1] as SimWaitSegment).waitSeconds, 3.0);
      expect((segments[2] as SimPathSegment).pathName, 'path2');
    });

    test('race group with path extracts path not wait', () {
      var seq = SequentialCommandGroup(commands: [
        RaceCommandGroup(commands: [
          PathCommand(pathName: 'path1'),
          WaitCommand(waitTime: 5.0),
        ]),
        PathCommand(pathName: 'path2'),
      ]);
      var segments = AutoSimulator.extractSimSegments(seq);
      // Race group contains a path → extract path, skip wait
      expect(segments.length, 2);
      expect((segments[0] as SimPathSegment).pathName, 'path1');
      expect((segments[1] as SimPathSegment).pathName, 'path2');
    });

    test('race group uses minimum of multiple waits', () {
      var seq = SequentialCommandGroup(commands: [
        RaceCommandGroup(commands: [
          WaitCommand(waitTime: 5.0),
          WaitCommand(waitTime: 2.0),
        ]),
      ]);
      var segments = AutoSimulator.extractSimSegments(seq);
      expect(segments.length, 1);
      expect((segments[0] as SimWaitSegment).waitSeconds, 2.0);
    });

    test('deadline group uses first child duration', () {
      var seq = SequentialCommandGroup(commands: [
        DeadlineCommandGroup(commands: [
          WaitCommand(waitTime: 3.0),
          NamedCommand(name: 'action'),
        ]),
      ]);
      var segments = AutoSimulator.extractSimSegments(seq);
      expect(segments.length, 1);
      expect((segments[0] as SimWaitSegment).waitSeconds, 3.0);
    });

    test('skips zero-duration wait commands', () {
      var seq = SequentialCommandGroup(commands: [
        PathCommand(pathName: 'path1'),
        WaitCommand(waitTime: 0),
        PathCommand(pathName: 'path2'),
      ]);
      var segments = AutoSimulator.extractSimSegments(seq);
      expect(segments.length, 2);
    });

    test('skips path commands with null name', () {
      var seq = SequentialCommandGroup(commands: [
        PathCommand(pathName: null),
        WaitCommand(waitTime: 1.0),
        PathCommand(pathName: 'path1'),
      ]);
      var segments = AutoSimulator.extractSimSegments(seq);
      expect(segments.length, 2);
      expect(segments[0], isA<SimWaitSegment>());
      expect((segments[1] as SimPathSegment).pathName, 'path1');
    });
  });

  group('simulateAuto with wait commands', () {
    late PathPlannerPath testPath;
    late PathPlannerPath testPath2;
    late RobotConfig config;

    setUp(() {
      testPath = PathPlannerPath(
        name: 'path1',
        waypoints: [
          Waypoint(
            anchor: const Translation2d(1, 1),
            nextControl: const Translation2d(3, 1),
          ),
          Waypoint(
            prevControl: const Translation2d(4, 3),
            anchor: const Translation2d(6, 3),
          ),
        ],
        globalConstraints: PathConstraints(),
        goalEndState: GoalEndState(0.0, const Rotation2d()),
        constraintZones: [
          ConstraintsZone(
              constraints: PathConstraints(),
              minWaypointRelativePos: 0.2,
              maxWaypointRelativePos: 0.4),
        ],
        pointTowardsZones: [PointTowardsZone()],
        rotationTargets: [
          RotationTarget(0.5, Rotation2d.fromDegrees(45)),
        ],
        eventMarkers: [],
        pathDir: '',
        fs: MemoryFileSystem(),
        reversed: false,
        folder: null,
        idealStartingState: IdealStartingState(0.0, const Rotation2d()),
        useDefaultConstraints: false,
      );

      testPath2 = PathPlannerPath(
        name: 'path2',
        waypoints: [
          Waypoint(
            anchor: const Translation2d(7, 3),
            nextControl: const Translation2d(9, 3),
          ),
          Waypoint(
            prevControl: const Translation2d(10, 5),
            anchor: const Translation2d(12, 5),
          ),
        ],
        globalConstraints: PathConstraints(),
        goalEndState: GoalEndState(0.0, const Rotation2d()),
        constraintZones: [
          ConstraintsZone(
              constraints: PathConstraints(),
              minWaypointRelativePos: 0.2,
              maxWaypointRelativePos: 0.4),
        ],
        pointTowardsZones: [PointTowardsZone()],
        rotationTargets: [
          RotationTarget(0.5, Rotation2d.fromDegrees(45)),
        ],
        eventMarkers: [],
        pathDir: '',
        fs: MemoryFileSystem(),
        reversed: false,
        folder: null,
        idealStartingState: IdealStartingState(0.0, const Rotation2d()),
        useDefaultConstraints: false,
      );

      config = RobotConfig(
        massKG: 70.0,
        moi: 6.8,
        moduleConfig: ModuleConfig(
          wheelRadiusMeters: 0.048,
          driveMotor: DCMotor.getKrakenX60(1).withReduction(5.12),
          driveCurrentLimit: 60,
          maxDriveVelocityMPS: 5.4,
          wheelCOF: 1.2,
        ),
        moduleLocations: const [
          Translation2d(0.25, 0.25),
          Translation2d(0.25, -0.25),
          Translation2d(-0.25, 0.25),
          Translation2d(-0.25, -0.25),
        ],
        holonomic: true,
        bumperSize: const Size(0.9, 0.9),
        bumperOffset: const Translation2d(),
      );
    });

    test('without sequence, behaves same as before', () {
      var sim = AutoSimulator.simulateAuto([testPath, testPath2], config);
      expect(sim, isNotNull);
      expect(sim!.states.last.timeSeconds, closeTo(8.25, 0.05));
    });

    test('with wait between paths adds wait duration', () {
      var seq = SequentialCommandGroup(commands: [
        PathCommand(pathName: 'path1'),
        WaitCommand(waitTime: 2.0),
        PathCommand(pathName: 'path2'),
      ]);

      var simWithWait = AutoSimulator.simulateAuto(
        [testPath, testPath2],
        config,
        sequence: seq,
      );
      var simWithout = AutoSimulator.simulateAuto(
        [testPath, testPath2],
        config,
      );

      expect(simWithWait, isNotNull);
      expect(simWithout, isNotNull);
      // Total time should be ~2 seconds longer with the wait
      expect(
        simWithWait!.states.last.timeSeconds,
        closeTo(simWithout!.states.last.timeSeconds + 2.0, 0.05),
      );
    });

    test('hold states have zero velocity', () {
      var seq = SequentialCommandGroup(commands: [
        PathCommand(pathName: 'path1'),
        WaitCommand(waitTime: 1.0),
        PathCommand(pathName: 'path2'),
      ]);

      var sim = AutoSimulator.simulateAuto(
        [testPath, testPath2],
        config,
        sequence: seq,
      );
      expect(sim, isNotNull);

      // Find states during the wait period (after path1 ends, ~3.82s)
      // The hold states should have zero field speeds
      var path1OnlyTime = AutoSimulator.simulateAuto([testPath], config)!
          .states
          .last
          .timeSeconds;
      var holdStates = sim!.states.where((s) =>
          s.timeSeconds >= path1OnlyTime &&
          s.timeSeconds <= path1OnlyTime + 1.0);
      expect(holdStates.isNotEmpty, true);
      for (var s in holdStates) {
        expect(s.fieldSpeeds.vx, 0.0);
        expect(s.fieldSpeeds.vy, 0.0);
      }
    });
  });
}
