import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/inkfold_theme.dart';

final class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.selectedIndex,
    required this.title,
    required this.body,
    this.actions = const <Widget>[],
    super.key,
  });

  final int selectedIndex;
  final String title;
  final Widget body;
  final List<Widget> actions;

  void _navigate(BuildContext context, int index) {
    context.go(index == 0 ? '/library' : '/settings');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        if (!wide) {
          return Scaffold(
            appBar: AppBar(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              actions: actions,
            ),
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _navigate(context, index),
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.library_books_outlined),
                  selectedIcon: Icon(Icons.library_books),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune),
                  label: 'Settings',
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: <Widget>[
              Container(
                width: 224,
                color: InkfoldTheme.ink,
                padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 32),
                      child: Row(
                        children: <Widget>[
                          _InkfoldMark(),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Inkfold',
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Literata',
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SideDestination(
                      icon: Icons.library_books_outlined,
                      label: 'Library',
                      selected: selectedIndex == 0,
                      onTap: () => _navigate(context, 0),
                    ),
                    const SizedBox(height: 6),
                    _SideDestination(
                      icon: Icons.tune_outlined,
                      label: 'Settings',
                      selected: selectedIndex == 1,
                      onTap: () => _navigate(context, 1),
                    ),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'TEXT READER  /  01',
                        style: TextStyle(color: Color(0xff9fa9a5), fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    Container(
                      height: 76,
                      color: Theme.of(context).colorScheme.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          ...actions,
                        ],
                      ),
                    ),
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

final class _InkfoldMark extends StatelessWidget {
  const _InkfoldMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: InkfoldTheme.oxblood,
      borderRadius: BorderRadius.circular(3),
    ),
    child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 18),
  );
}

final class _SideDestination extends StatelessWidget {
  const _SideDestination({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xff34413f) : Colors.transparent,
    borderRadius: BorderRadius.circular(5),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: selected ? Colors.white : const Color(0xffb7c0bd)),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xffb7c0bd))),
          ],
        ),
      ),
    ),
  );
}
