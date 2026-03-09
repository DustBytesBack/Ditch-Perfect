import 'package:flutter/material.dart';

import 'database_service.dart';

class TutorialTargets {
  static const homeOverview = 'tutorial.home.overview';
  static const homeQuickAdd = 'tutorial.home.quickAdd';
  static const homeBulkActions = 'tutorial.home.bulkActions';
  static const homeFirstSubjectRow = 'tutorial.home.firstSubjectRow';
  static const navBar = 'tutorial.nav.bar';
  static const navRank = 'tutorial.nav.rank';
  static const subjectAdd = 'tutorial.subject.add';
  static const subjectFirstCard = 'tutorial.subject.firstCard';
  static const calendarMain = 'tutorial.calendar.main';
  static const calendarStats = 'tutorial.calendar.stats';
  static const settingsTutorialRestart = 'tutorial.settings.restart';
}

class TutorialService {
  static const String _completionKey = 'onboardingTutorialCompleted';

  static final Map<String, GlobalKey> _keys = <String, GlobalKey>{};
  static final ValueNotifier<int> restartListenable = ValueNotifier<int>(0);

  static GlobalKey keyFor(String id) {
    return _keys.putIfAbsent(id, () => GlobalKey(debugLabel: id));
  }

  static Rect? rectFor(String id) {
    final context = _keys[id]?.currentContext;
    if (context == null) return null;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & renderObject.size;
  }

  static bool get isCompleted {
    return DatabaseService.settingsBox.get(_completionKey, defaultValue: false)
        as bool;
  }

  static Future<void> markCompleted() async {
    await DatabaseService.settingsBox.put(_completionKey, true);
  }

  static Future<void> reset() async {
    await DatabaseService.settingsBox.put(_completionKey, false);
  }

  static Future<void> requestRestart() async {
    await reset();
    restartListenable.value++;
  }
}
