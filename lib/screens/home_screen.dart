import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:better_player/better_player.dart';
import '../models/channel.dart';
import '../models/theme.dart';
import '../widgets/channel_card.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Channel? _activeChannel;
  BetterPlayerController? _miniController;
  bool _miniLoading = false;
  bool _miniError = false;

  void _selectChannel(Channel ch) {
    if (_activeChannel?.id == ch.id) {
      // Open fullscreen
      _openFullscreen(ch);
      return;
    }
    setState(() {
      _activeChannel = ch;
      _miniLoading = true;
      _miniError = false;
    });
    _loadMiniPlayer(ch);
  }

  void _loadMiniPlayer(Channel ch) {
    _miniController?.dispose();

    final ds = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      ch.streamUrl,
      liveStream: true,
      videoFormat: BetterPlayerVideoFormat.hls,
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 1500,
        maxBufferMs: 8000,
        bufferForPlaybackMs: 1000,
        bufferForPlaybackAfterRebufferMs: 2000,
      ),
    );

    _miniController = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
        ),
        eventListener: (event) {
          if (event.betterPlayerEventType ==
              BetterPlayerEventType.initialized) {
            if (mounted) setState(() => _miniLoading = false);
          } else if (event.betterPlayerEventType ==
              BetterPlayerEventType.exception) {
            if (mounted) setState(() {
              _miniLoading = false;
              _miniError = true;
            });
          }
        },
      ),
      betterPlayerDataSource: ds,
    );
    setState(() {});
  }

  void _openFullscreen(Channel ch) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PlayerScreen(channel: ch),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ).then((_) {
      // Back from fullscreen - resume mini player
      if (_activeChannel != null) {
        _loadMiniPlayer(_activeChannel!);
      }
    });
  }

  @override
  void dispose() {
    _miniController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.bg.withOpacity(0.95),
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ColorFilter.matrix([
                  1, 0, 0, 0, 0,
                  0, 1, 0, 0, 0,
                  0, 0, 1, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
                child: const SizedBox.expand(),
              ),
            ),
            title: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accent, AppTheme.accentDim],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.tv_rounded,
                      color: Colors.black, size: 18),
                ),
                const SizedBox(width: 10),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.text,
                      letterSpacing: -0.5,
                    ),
                    children: [
                      TextSpan(text: 'ilyass '),
                      TextSpan(
                        text: 'tv',
                        style: TextStyle(color: AppTheme.accent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.live.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.live.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulseDot(color: AppTheme.live),
                    const SizedBox(width: 5),
                    const Text(
                      'بث مباشر',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.live,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: AppTheme.border,
              ),
            ),
          ),

          // ── Mini Player ──
          if (_activeChannel != null)
            SliverToBoxAdapter(
              child: _buildMiniPlayer(),
            ),

          // ── Section header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Row(
                children: [
                  const Text(
                    'القنوات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${kChannels.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDim,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
          ),

          // ── Channels Grid ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final ch = kChannels[index];
                  return ChannelCard(
                    channel: ch,
                    isActive: _activeChannel?.id == ch.id,
                    onTap: () => _selectChannel(ch),
                    index: index,
                  );
                },
                childCount: kChannels.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    final ch = _activeChannel!;
    return GestureDetector(
      onTap: () => _openFullscreen(ch),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Column(
          children: [
            // Video
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(17)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Player
                    if (_miniController != null && !_miniError)
                      BetterPlayer(controller: _miniController!),

                    // Loading
                    if (_miniLoading)
                      Container(
                        color: Colors.black,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                color: AppTheme.accent,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'جاري التحميل...',
                              style: TextStyle(
                                color: AppTheme.textDim,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Error
                    if (_miniError)
                      Container(
                        color: Colors.black,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off_rounded,
                                color: AppTheme.live, size: 32),
                            SizedBox(height: 8),
                            Text(
                              'تعذر التحميل',
                              style: TextStyle(
                                  color: AppTheme.textDim, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                    // Fullscreen hint
                    if (!_miniLoading)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fullscreen_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Now playing info
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(17)),
              ),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: CachedNetworkImage(
                      imageUrl: ch.logoUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.tv_rounded,
                          color: AppTheme.textDim,
                          size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ch.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _PulseDot(color: AppTheme.live, size: 5),
                            const SizedBox(width: 5),
                            const Text(
                              'بث مباشر الآن',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.live,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Fullscreen button
                  GestureDetector(
                    onTap: () => _openFullscreen(ch),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.open_in_full_rounded,
                          color: AppTheme.accent, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .slideY(begin: -0.1, end: 0, duration: 300.ms),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const _PulseDot({required this.color, this.size = 6});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _a = Tween(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _a,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      );
}
