import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/apps_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/get_button.dart';
import 'app_details_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favs = context.watch<AppsProvider>().favorites;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text('Favorites',
                  style: AppTheme.sf(size: 28, weight: FontWeight.w800)),
            ),
            if (favs.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite_border_rounded,
                          color: AppTheme.textTertiary, size: 54),
                      const SizedBox(height: 14),
                      Text('No favorites yet',
                          style: AppTheme.sf(
                              size: 15, color: AppTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Text('Tap ♥ on any app to save it',
                          style: AppTheme.sf(
                              size: 13, color: AppTheme.textTertiary)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: favs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppTheme.separator, indent: 74),
                  itemBuilder: (ctx, i) {
                    final app = favs[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AppDetailsScreen(app: app)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Hero(
                              tag: 'icon_${app.id}',
                              child: AppIcon(
                                  iconUrl: app.icon,
                                  name: app.name,
                                  size: 60,
                                  radius: 14),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(app.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.sf(
                                          size: 15,
                                          weight: FontWeight.w600)),
                                  const SizedBox(height: 3),
                                  Text(
                                    app.developer.isNotEmpty
                                        ? app.developer
                                        : 'App',
                                    style: AppTheme.sf(
                                        size: 12,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            GetButton(app: app),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
