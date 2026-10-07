import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'screens/settings_screen.dart';
import 'screens/shell.dart';
import 'services/dictionary.dart';
import 'services/speech.dart';
import 'services/store.dart';
import 'theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: C.ground,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  final docs = await getApplicationDocumentsDirectory();
  final library = Library(FileStorage(docs.path));
  await library.load();
  Speech.instance.rate = library.settings.speechRate;
  runApp(ManabeeApp(library: library, dictionary: AppDictionary()));
}

class ManabeeApp extends StatelessWidget {
  const ManabeeApp({
    super.key,
    required this.library,
    required this.dictionary,
  });

  final Library library;
  final Dictionary dictionary;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      library: library,
      dictionary: dictionary,
      child: MaterialApp(
        title: 'manabee',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const Shell(),
        routes: {'/settings': (_) => const SettingsScreen()},
      ),
    );
  }
}
