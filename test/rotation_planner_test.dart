import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/services/rotation_planner.dart';

void main() {
  test('reported bug: pp -> full body -> pp, legs never done -> legs first', () {
    final order = ['pp', 'fb', 'legs'];
    final lastDone = {
      'pp': DateTime(2026, 6, 16),
      'fb': DateTime(2026, 6, 10),
      // legs absent -> never done
    };
    expect(rankRotationByMostOverdue(order, lastDone), ['legs', 'fb', 'pp']);
  });

  test('clean in-order rotation keeps cycling oldest-first', () {
    final order = ['pp', 'legs', 'fb'];
    final lastDone = {
      'pp': DateTime(2026, 6, 1),
      'legs': DateTime(2026, 6, 2),
      'fb': DateTime(2026, 6, 3),
    };
    // Oldest done = pp -> suggested next.
    expect(rankRotationByMostOverdue(order, lastDone).first, 'pp');
  });

  test('never-done routine jumps ahead of all done routines', () {
    final order = ['a', 'b', 'c'];
    final lastDone = {
      'a': DateTime(2026, 6, 20),
      'b': DateTime(2026, 6, 5),
      // c never done
    };
    expect(rankRotationByMostOverdue(order, lastDone), ['c', 'b', 'a']);
  });

  test('same-day tie preserves rotation list order', () {
    final order = ['a', 'b'];
    final d = DateTime(2026, 6, 10);
    final lastDone = {'a': d, 'b': d};
    expect(rankRotationByMostOverdue(order, lastDone), ['a', 'b']);
  });

  test('nothing done yet -> rotation list order unchanged', () {
    final order = ['a', 'b', 'c'];
    expect(rankRotationByMostOverdue(order, {}), ['a', 'b', 'c']);
  });

  test('empty rotation -> empty list', () {
    expect(rankRotationByMostOverdue([], {}), isEmpty);
  });

  test('multiple never-done routines preserve list order among themselves', () {
    final order = ['a', 'b', 'c', 'd'];
    final lastDone = {'b': DateTime(2026, 6, 9)};
    // never-done a, c, d first (in list order), then b.
    expect(rankRotationByMostOverdue(order, lastDone), ['a', 'c', 'd', 'b']);
  });
}
