import 'package:flutter/widgets.dart';

import 'app.dart';
import 'config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CoopVoteApp(entryUri: AppConfig.entryUri));
}
