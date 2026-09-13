import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/daos/meetings_dao.dart';

/// Every meeting with its counts, newest first. Watched, so a chunk landing
/// during a recording updates the row in place without a refresh.
final meetingSummariesProvider = StreamProvider<List<MeetingSummary>>((ref) {
  return ref.watch(appDatabaseProvider).meetingsDao.watchMeetingSummaries();
});
