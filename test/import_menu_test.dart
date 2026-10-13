import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabee/main.dart';
import 'package:manabee/screens/import_screen.dart';
import 'package:manabee/services/jisho.dart';
import 'package:manabee/services/store.dart';

void main() {
  testWidgets('adding pages offers the camera and photos by date taken', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final lib = Library(MemoryStorage());
    await tester.pumpWidget(ManabeeApp(library: lib, dictionary: Jisho()));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute(builder: (_) => const ImportScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ add new page/folder'));
    await tester.pumpAndSettle();
    expect(find.text('Photograph pages'), findsOneWidget);
    expect(find.text('Photos, by date taken'), findsOneWidget);
    expect(find.text('Page images'), findsOneWidget);
    expect(find.text('Archive (.cbz / .zip)'), findsOneWidget);
  });
}
