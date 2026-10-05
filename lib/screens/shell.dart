/// The three tabs and the dock beneath them. Each tab keeps its own
/// navigator, so the dock stays put while you go deeper (a manga, its
/// words, a flash-card run) and each tab remembers where you were. The
/// reader is pushed above all of it, full screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'collections_screen.dart';
import 'home_screen.dart';
import 'study_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  final _keys = List.generate(3, (_) => GlobalKey<NavigatorState>());

  static const _roots = <Widget>[
    HomeScreen(),
    CollectionsScreen(),
    StudyScreen(),
  ];

  void _select(int i) {
    if (i == _tab) {
      _keys[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _tab = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _keys[_tab].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (_tab != 0) {
          setState(() => _tab = 0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: C.ground,
        body: IndexedStack(
          index: _tab,
          children: [
            for (var i = 0; i < 3; i++)
              HeroControllerScope.none(
                child: Navigator(
                  key: _keys[i],
                  onGenerateRoute: (_) =>
                      MaterialPageRoute(builder: (_) => _roots[i]),
                ),
              ),
          ],
        ),
        bottomNavigationBar: Dock(index: _tab, onSelect: _select),
      ),
    );
  }
}

class Dock extends StatelessWidget {
  const Dock({super.key, required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _icons = [
    (Icons.home_outlined, 'Library'),
    (Icons.chat_bubble_outline_rounded, 'Words'),
    (Icons.inventory_2_outlined, 'Study'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Color(0x1FFFFFFF))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < _icons.length; i++)
                Tooltip(
                  message: _icons[i].$2,
                  child: InkResponse(
                    onTap: () => onSelect(i),
                    radius: 30,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == index ? Colors.white : Colors.transparent,
                      ),
                      child: Icon(
                        _icons[i].$1,
                        color: i == index ? Colors.black : Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
