import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Disable SplashScreen timers/animations when set (used by CI/tests)
const bool kDisableSplashTimers = bool.fromEnvironment(
  'DISABLE_SPLASH_TIMERS',
  defaultValue: false,
);

class SplashScreen extends StatefulWidget {
  final VoidCallback onSplashFinished;

  const SplashScreen({super.key, required this.onSplashFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _fadeController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _fadeOut;

  // CI/CD build number (provided via --dart-define=BUILD_NUMBER=123), empty locally
  final String _buildNumber = const String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: '',
  );

  // App version from pubspec.yaml
  String _appVersion = '';

  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadVersionInfo();
    _startAnimationSequence();
  }

  void _initializeAnimations() {
    // Logo animation controller (scale and fade in)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Text animation controller (fade and slide)
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Fade out controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Logo animations
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // Text animations
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    // Fade out animation
    _fadeOut = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
  }

  Future<void> _loadVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      // Fallback values if package info fails
      setState(() {
        _appVersion = '0.1.0';
      });
    }
  }

  void _startAnimationSequence() async {
    if (kDisableSplashTimers) {
      // Skip animations/timers during tests/CI to avoid pending timers.
      return;
    }
    // Start logo animation immediately
    _logoController.forward();

    // Wait a bit, then start text animation
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      _textController.forward();
    }

    // Wait for animations to complete, then hold for minimum splash time
    await Future.delayed(const Duration(milliseconds: 2000));

    // Wait until not paused before finishing
    while (_isPaused) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Start fade out and finish
    if (mounted) {
      _fadeController.forward().then((_) {
        if (mounted) {
          widget.onSplashFinished();
        }
      });
    }
  }

  void _toggleTimer() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  String _formatVersionString() {
    final parts = <String>[];
    if (_appVersion.isNotEmpty) parts.add('v$_appVersion');
    if (_buildNumber.isNotEmpty) parts.add('#$_buildNumber');
    final label = parts.join(' ');
    return label.isNotEmpty ? 'Version $label' : 'Version';
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900], // Dark charcoal instead of blue
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _logoController,
          _textController,
          _fadeController,
        ]),
        builder: (context, child) {
          return Opacity(
            opacity: _fadeOut.value,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2C2C2C),
                    Color(0xFF1A1A1A),
                  ], // Dark gradient
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // App Name with modern styling
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: const Text(
                          'Gravel First',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tagline
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: Text(
                          'Plan gravel bike routes with interactive maps',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w300,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Logo with modern hexagonal frame
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoOpacity,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0175C2,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              40,
                            ), // Rounded square
                            border: Border.all(
                              color: const Color(
                                0xFF0175C2,
                              ).withValues(alpha: 0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0175C2,
                                ).withValues(alpha: 0.2),
                                blurRadius: 40,
                                offset: const Offset(0, 10),
                                spreadRadius: 5,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              width: 210,
                              height: 210,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Version and Build Info
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: GestureDetector(
                          onTap: _toggleTimer,
                          child: Column(
                            children: [
                              Text(
                                _formatVersionString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _isPaused
                                      ? Colors.amber
                                      : Colors.grey[500],
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              if (_isPaused)
                                Text(
                                  '⏸ PAUSED - Tap to resume',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                'Copyright © AOLI 2025',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
