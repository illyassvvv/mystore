import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import 'dart:ui';
import 'core.dart';
import 'widgets.dart';

class AppDetailsScreen extends StatefulWidget {
  final AppModel app;
  final StoreController ctrl;

  const AppDetailsScreen({
    super.key,
    required this.app,
    required this.ctrl,
  });

  @override
  State<AppDetailsScreen> createState() => _AppDetailsScreenState();
}

class _AppDetailsScreenState extends State<AppDetailsScreen> {
  Color? dominantColor;
  late ScrollController _scrollController;
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(() {
      _scrollOffset.value = _scrollController.offset;
    });
    _extractColor();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  Future<void> _extractColor() async {
    try {
      final PaletteGenerator gen = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(widget.app.icon),
      );
      if (mounted) setState(() => dominantColor = gen.dominantColor?.color);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color glow = dominantColor ?? (isDark ? Colors.white : Colors.black);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Reactive Ambient Glow System
          ValueListenableBuilder<double>(
            valueListenable: _scrollOffset,
            builder: (context, offset, child) {
              double inverseParallax = -(offset * 0.4);
              double opacity = (1.0 - (offset / 350)).clamp(0.0, 1.0);
              return Positioned(
                top: -120 + inverseParallax,
                left: -80,
                right: -80,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: opacity,
                  child: Container(
                    height: 450,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          glow.withOpacity(isDark ? 0.35 : 0.15),
                          Colors.transparent
                        ],
                        radius: 0.8,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // Advanced Glass Morphism Navigation Bar
              SliverPersistentHeader(
                pinned: true,
                delegate: _GlassHeaderDelegate(
                  app: widget.app,
                  scrollOffsetNotifier: _scrollOffset,
                  safeAreaTop: MediaQuery.of(context).padding.top,
                  isDark: isDark,
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Depth System & Micro Parallax
                          ValueListenableBuilder<double>(
                            valueListenable: _scrollOffset,
                            builder: (context, offset, child) {
                              double parallax = (offset * 0.15).clamp(0.0, 50.0);
                              double shadowBlur = (40.0 - (offset * 0.15)).clamp(10.0, 40.0);
                              double shadowOp = (0.5 - (offset * 0.002)).clamp(0.0, 0.5);
                              return Transform.translate(
                                offset: Offset(0, parallax),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: glow.withOpacity(shadowOp),
                                        blurRadius: shadowBlur,
                                        offset: const Offset(0, 15),
                                      )
                                    ],
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: Hero(
                              tag: 'icon_${widget.app.name}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: CachedNetworkImage(
                                  imageUrl: widget.app.icon,
                                  width: 118,
                                  height: 118,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Reactive Title Transition
                                ValueListenableBuilder<double>(
                                  valueListenable: _scrollOffset,
                                  builder: (context, offset, child) {
                                    double moveUp = (offset * 0.35).clamp(0.0, 40.0);
                                    double scale = (1.0 - (offset * 0.0015)).clamp(0.85, 1.0);
                                    double opacity = (1.0 - (offset / 120)).clamp(0.0, 1.0);
                                    return Transform.translate(
                                      offset: Offset(0, -moveUp),
                                      child: Transform.scale(
                                        scale: scale,
                                        alignment: Alignment.centerLeft,
                                        child: Opacity(
                                          opacity: opacity,
                                          child: child,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.app.name,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).textTheme.bodyLarge?.color,
                                          letterSpacing: -0.6,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Version ${widget.app.version}",
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Morphing iOS 26 Button
                                _MorphingGlassButton(app: widget.app, ctrl: widget.ctrl),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      _BlurredDivider(isDark: isDark),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoBlock("SIZE", widget.app.size, context),
                          _buildInfoBlock("AGE", widget.app.age, context),
                          _buildInfoBlock("CHART", widget.app.chart, context),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _BlurredDivider(isDark: isDark),
                      const SizedBox(height: 24),

                      const Text(
                        "What's New",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Version ${widget.app.version}\nIncludes latest bug fixes, performance improvements, and local smart caching.",
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                          height: 1.5,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 30),

                      const Text(
                        "Description",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.app.description,
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                          height: 1.5,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock(String title, String value, BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ],
    );
  }
}

class _GlassHeaderDelegate extends SliverPersistentHeaderDelegate {
  final AppModel app;
  final ValueNotifier<double> scrollOffsetNotifier;
  final double safeAreaTop;
  final bool isDark;

  _GlassHeaderDelegate({
    required this.app,
    required this.scrollOffsetNotifier,
    required this.safeAreaTop,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ValueListenableBuilder<double>(
      valueListenable: scrollOffsetNotifier,
      builder: (context, offset, _) {
        double progress = (offset / 120).clamp(0.0, 1.0);
        double blurValue = progress * 40.0;
        double glassOpacity = progress * (isDark ? 0.55 : 0.65);
        double borderOpacity = progress * 0.15;

        return ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
            child: Container(
              height: maxExtent,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(glassOpacity)
                    : Colors.white.withOpacity(glassOpacity),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withOpacity(borderOpacity),
                    width: 0.5,
                  ),
                ),
              ),
              padding: EdgeInsets.only(top: safeAreaTop),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppleBouncingButton(
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.back,
                              color: Theme.of(context).primaryColor,
                              size: 28,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              "Store",
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: progress,
                      child: Transform.translate(
                        offset: Offset(0, 15 * (1 - progress)),
                        child: Text(
                          app.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  double get maxExtent => safeAreaTop + 44.0;
  @override
  double get minExtent => safeAreaTop + 44.0;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class _MorphingGlassButton extends StatelessWidget {
  final AppModel app;
  final StoreController ctrl;

  const _MorphingGlassButton({
    required this.app,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: ValueListenableBuilder<DownloadState>(
        valueListenable: app.stateNotifier,
        builder: (context, state, child) {
          bool isDownloading = state == DownloadState.downloading || state == DownloadState.paused;
          bool isDownloaded = state == DownloadState.downloaded;

          return AppleBouncingButton(
            onTap: () {
              if (isDownloading) {
                state == DownloadState.paused ? ctrl.start(app) : ctrl.pause(app);
              } else if (isDownloaded) {
                ctrl.saveToFile(app);
              } else {
                ctrl.start(app);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              width: isDownloading ? 220 : 90,
              height: 38,
              decoration: BoxDecoration(
                color: isDownloading
                    ? (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E5EA))
                    : (isDownloaded
                        ? (isDark ? Colors.white24 : Colors.black12)
                        : Theme.of(context).primaryColor),
                borderRadius: BorderRadius.circular(isDownloading ? 24 : 20),
                border: Border.all(
                  color: Colors.white.withOpacity(isDark ? 0.08 : 0.3),
                  width: 0.5,
                ),
                boxShadow: [
                  if (!isDownloading && !isDownloaded)
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                ],
              ),
              child: Stack(
                children: [
                  // Glass Highlight Reflection
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.2),
                            Colors.transparent
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: isDownloading
                          ? _buildProgressCapsule(context, isDark)
                          : Text(
                              isDownloaded ? "SAVE" : "GET",
                              key: ValueKey(isDownloaded),
                              style: TextStyle(
                                color: isDownloaded
                                    ? Theme.of(context).primaryColor
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: -0.2,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressCapsule(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ValueListenableBuilder<double>(
        valueListenable: app.progressNotifier,
        builder: (context, progress, _) {
          bool isPaused = app.stateNotifier.value == DownloadState.paused;
          return Row(
            key: const ValueKey("progress"),
            children: [
              Icon(
                isPaused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
                color: Theme.of(context).primaryColor,
                size: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.black26 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => ctrl.cancel(app),
                child: const Icon(
                  CupertinoIcons.stop_fill,
                  color: Colors.redAccent,
                  size: 16,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BlurredDivider extends StatelessWidget {
  final bool isDark;
  
  const _BlurredDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
