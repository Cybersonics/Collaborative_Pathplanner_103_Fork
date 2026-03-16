import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/auto_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/command_group_widget.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/reset_odom_tree.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

void main() {
  late PathPlannerAuto auto;
  bool sideSwapped = false;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    auto = PathPlannerAuto.defaultAuto(
      autoDir: '/autos',
      fs: MemoryFileSystem(),
    );
    sideSwapped = false;
  });

  testWidgets('has simulated auto time', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AutoTree(
          auto: auto,
          undoStack: ChangeStack(),
          allPathNames: const [],
          prefs: prefs,
        ),
      ),
    ));

    expect(find.textContaining('Simulated Auto Time'), findsOneWidget);
  });

  testWidgets('swap side button', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AutoTree(
          auto: auto,
          undoStack: ChangeStack(),
          allPathNames: const [],
          prefs: prefs,
          onSideSwapped: () => sideSwapped = true,
        ),
      ),
    ));

    var btn = find.byTooltip('Move to Other Side');

    expect(btn, findsOneWidget);

    await widgetTester.tap(btn);
    await widgetTester.pump();
    expect(sideSwapped, true);
  });

  testWidgets('has command group', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AutoTree(
          auto: auto,
          undoStack: ChangeStack(),
          allPathNames: const [],
          prefs: prefs,
        ),
      ),
    ));

    expect(find.byType(CommandGroupWidget), findsWidgets);
  });

  testWidgets('has reset odom check', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AutoTree(
          auto: auto,
          undoStack: ChangeStack(),
          allPathNames: const [],
          prefs: prefs,
        ),
      ),
    ));

    expect(find.byType(ResetOdomTree), findsWidgets);
  });
}
