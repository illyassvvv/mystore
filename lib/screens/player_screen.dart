import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player/better_player.dart';
import '../models/channel.dart';
import '../models/theme.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;

  const PlayerScreen({super.key, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  BetterPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Lock to landscape for fullscreen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initPlayer();
  }

  void _initPlayer() {
    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.channel.streamUrl,
      liveStream: true,
      videoFormat: BetterPlayerVideoFormat.hls,
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 2000,
        maxBufferMs: 10000,
        bufferForPlaybackMs: 1500,
        bufferForPlaybackAfterRebufferMs: 3000,
      ),
    );

    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        looping: false,
        fullScreenByDefault: false,
        allowedScreenSleep: false,
        autoDetectFullscreenAspectRatio: true,
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enableFullscreen: true,
          enablePlayPause: true,
          enableSkips: false,
          enableMute: true,
          enableAudioTracks: false,
          enableQualities: false,
          enableSubtitles: false,
          enableOverflowMenu: false,
          controlBarColor: Colors.black54,
          loadingColor: AppTheme.accent,
          progressBarPlayedColor: AppTheme.accent,
          progressBarBufferedColor: AppTheme.accent.withOpacity(0.3),
          progressBarBackgroundColor: Colors.white24,
          iconsColor: Colors.white,
          playIcon: Icons.play_arrow_rounded,
          pauseIcon: Icons.pause_rounded,
          liveTextColor: AppTheme.live,
          showControlsOnInitialize: false,
        ),
        eventListener: (event) {
          if (event.betterPlayerEventType ==
              BetterPlayerEventType.initialized) {
            if (mounted) setState(() => _isLoading = false);
          } else if (event.betterPlayerEventType ==
              BetterPlayerEventType.exception) {
            if (mounted) setState(() { _isLoading = false; _hasError = true; });
          }
        },
      ),
      betterPlayerDataSource: dataSource,
    );
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Player
          if (_controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: BetterPlayer(controller: _controller!),
              ),
            ),

          // Loading
          if (_isLoading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: AppTheme.accent,
                    strokeWidth: 2.5,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'جاري تحميل ${widget.channel.name}...',
                    style: const TextStyle(
                      color: AppTheme.textDim,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Error
          if (_hasError)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: AppTheme.live, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'تعذر تحميل القناة',
                    style: TextStyle(
                      color: AppTheme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      setState(() { _isLoading = true; _hasError = false; });
                      _controller?.dispose();
                      _initPlayer();
                    },
                    child: const Text('إعادة المحاولة',
                        style: TextStyle(color: AppTheme.accent)),
                  ),
                ],
              ),
            ),

          // Back button
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),

          // Channel name top-left
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.live,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.channel.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
