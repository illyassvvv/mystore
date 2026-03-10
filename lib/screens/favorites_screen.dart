import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_model.dart';
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
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  Text('Favorites',
                      style: t.sf(size: 28, weight: FontWeight.w800)),
                  const Spacer(),
                  if (favs.isNotEmpty)
                    Text(
                        '${favs.length} app${favs.length == 1 ? '' : 's'}',
                        style: t.sf(size: 13, color: t.textSec)),
                ],
              ),
            ),
            if (favs.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.favorite_border_rounded,
                            color: AppColors.red, size: 34),
                      ),
                      const SizedBox(height: 16),
                      Text('No favorites yet',
                          style: t.sf(size: 16, weight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Tap ♥ on any app to save it',
                          style: t.sf(size: 13, color: t.textSec)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: favs.length,
                  itemBuilder: (ctx, i) {
                    final AppModel app = favs[i];
                    return _FavCard(
                      app: app,
                      t: t,
                      onTap: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (_) => AppDetailsScreen(app: app)),
                      ),
                      onRemove: () {
                        HapticFeedback.lightImpact();
                        provider.toggleFav(app.id);
                      },
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

class _FavCard extends StatefulWidget {
  final AppModel app;
  final AppTheme t;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _FavCard(
      {required this.app,
      required this.t,
      required this.onTap,
      required this.onRemove});

  @override
  State<_FavCard> createState() => _FavCardState();
}

class _FavCardState extends State<_FavCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;
  late final Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _scale = Tween(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _ac, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final t = widget.t;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ac.forward(),
      onTapUp: (_) {
        _ac.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ac.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withOpacity(t.isDark ? 0.20 : 0.07),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'app_icon_${app.id}',
                    child: AppIcon(
                        iconUrl: app.icon,
                        name: app.name,
                        size: 56,
                        radius: 13),
                  ),
                  const Spacer(),
                  // Heart with bounce animation
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _ac.forward(from: 0).then((_) => _ac.reverse());
                      widget.onRemove();
                    },
                    child: ScaleTransition(
                      scale: _heartScale,
                      child: const Icon(Icons.favorite_rounded,
                          color: AppColors.red, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(app.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.sf(
                      size: 13, weight: FontWeight.w600, height: 1.3)),
              const SizedBox(height: 3),
              Text(
                app.developer.isNotEmpty ? app.developer : app.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.sf(size: 11, color: t.textSec),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: GetButton(app: app),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
