/// Ranks the routine IDs in [order] so the most "overdue" routine comes first.
///
/// [order] is the configured rotation (a list of routine IDs).
/// [lastDoneById] maps a routine ID to the date of its most recent completed
/// workout. A routine ID absent from the map has never been completed and is
/// treated as the most overdue.
///
/// Ranking: never-done routines first, then by last-done date oldest-first.
/// Ties (both never-done, or equal dates) preserve the routine's position in
/// [order].
List<String> rankRotationByMostOverdue(
  List<String> order,
  Map<String, DateTime> lastDoneById,
) {
  // Pair each routine with its original index so ties resolve to list order
  // regardless of the sort algorithm's stability.
  final indexed = <MapEntry<int, String>>[
    for (var i = 0; i < order.length; i++) MapEntry(i, order[i]),
  ];

  indexed.sort((a, b) {
    final da = lastDoneById[a.value];
    final db = lastDoneById[b.value];

    if (da == null && db == null) return a.key.compareTo(b.key);
    if (da == null) return -1; // a never done -> most overdue -> first
    if (db == null) return 1; // b never done -> most overdue -> first

    final byDate = da.compareTo(db); // older date first
    if (byDate != 0) return byDate;
    return a.key.compareTo(b.key); // same date -> list order
  });

  return [for (final entry in indexed) entry.value];
}
