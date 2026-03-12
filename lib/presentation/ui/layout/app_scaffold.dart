import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:theatre_121/config/app_routes.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final String? browserTitle;
  final int currentIndex;
  final bool showBottomNav;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;

  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.browserTitle,
    this.currentIndex = 0,
    this.showBottomNav = false,
    this.actions,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    final pageTitle = browserTitle ?? title ?? 'Theatre 121';

    return Title(
      color: Theme.of(context).primaryColor,
      title: pageTitle,
      child: Scaffold(
      appBar: appBar ??
          (title != null
              ? AppBar(
                  leading: context.canPop()
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back),
                          tooltip: null,
                          onPressed: () => context.pop(),
                        )
                      : null,
                  titleSpacing: context.canPop() ? 0 : 16,
                  title: Text(title!),
                  actions: [
                    if (actions != null) ...actions!,
                    const SizedBox(width: 12),
                  ],
                )
              : null),
      body: body,
      bottomNavigationBar: showBottomNav
          ? BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (index) => _onNavTap(context, index),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.how_to_vote),
                  label: 'Ballot',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.favorite),
                  label: 'Donate',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.theater_comedy),
                  label: 'Theatre 121',
                ),
              ],
            )
          : null,
      ),
    );
  }

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        // Already on ballot - do nothing or refresh
        break;
      case 1:
        _launchUrl(AppRoutes.externalDonate);
        break;
      case 2:
        _launchUrl(AppRoutes.externalTheatre121);
        break;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
