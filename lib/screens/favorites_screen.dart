import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/apps_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/get_button.dart';
import 'app_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<AppsProvider>();
    final t = AppTheme(context.watch<ThemeProvider>().isDark);
    final favs = provider.favorites;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text('Favorites',
                  style: t.sf(size: 28, weight: FontWeight.w800)),
            ),
            if (favs.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border_rounded,
                          color: t.textTer, size: 54),
                      const SizedBox(height: 14),
                      Text('No favorites yet',
                          style: t.sf(size: 15, color: t.textSec)),
                      const SizedBox(height: 6),
                      Text('Tap ♥ on any app to save it',
                          style: t.sf(size: 13, color: t.textTer)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  itemCount: favs.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: t.separator, indent: 76),
                  itemBuilder: (ctx, i) {
                    final app = favs[i];
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AppDetailsScreen(app: app)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(
                          children: [
                            Hero(
                              tag: 'app_icon_${app.id}',
                              child: AppIcon(
                                  iconUrl: app.icon,
                                  name: app.name,
                                  size: 62,
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
                                      style: t.sf(
                                          size: 15,
                                          weight: FontWeight.w600)),
                                  const SizedBox(height: 3),
                                  Text(
                                    app.developer.isNotEmpty
                                        ? app.developer
                                        : app.category,
                                    style: t.sf(
                                        size: 12, color: t.textSec),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {},
                              child: GetButton(app: app),
                            ),
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
