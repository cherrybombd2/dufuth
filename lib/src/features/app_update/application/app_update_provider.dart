import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_update_repository.dart';

final appUpdateGateProvider = FutureProvider<AppUpdateGateResult>((ref) {
  return ref.read(appUpdateRepositoryProvider).checkForRequiredUpdate();
});
