import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/report.dart';
import 'review_screen.dart';

class AIAnalysisScreen extends StatefulWidget {
  final File imageFile;
  final Report report;

  const AIAnalysisScreen({
    super.key,
    required this.imageFile,
    required this.report,
  });

  @override
  State<AIAnalysisScreen> createState() => _AIAnalysisScreenState();
}

class _AIAnalysisScreenState extends State<AIAnalysisScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late AnimationController _scanController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _fadeAnimation;

  Timer? _analysisTimer;
  double _currentProgress = 0.0;
  String _currentStatus = 'Initializing AI analysis...';

  final List<String> _statusMessages = [
    'Initializing AI analysis...',
    'Scanning image for defects...',
    'Detecting object boundaries...',
    'Analyzing surface conditions...',
    'Measuring damage severity...',
    'Classifying issue type...',
    'Finalizing assessment...',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnalysis();
  }

  void _initializeAnimations() {
    // Main animation controller for overall sequence
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Pulse animation for the AI brain icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Progress animation for the progress bar
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // Scan line animation
    _scanController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // Pulse animation
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Progress animation
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // Scan line animation
    _scanAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scanController, curve: Curves.linear));

    // Fade animation for status messages
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _mainController, curve: Curves.easeIn));

    // Start all animations
    _mainController.forward();
    _progressController.forward();
  }

  void _startAnalysis() {
    int statusIndex = 0;

    _analysisTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _currentProgress = (statusIndex + 1) / _statusMessages.length;
        if (statusIndex < _statusMessages.length) {
          _currentStatus = _statusMessages[statusIndex];
          statusIndex++;
        }
      });

      // Complete the analysis after all messages
      if (statusIndex >= _statusMessages.length) {
        timer.cancel();
        _completeAnalysis();
      }
    });
  }

  void _completeAnalysis() {
    // Add a slight delay before navigating to review screen
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewScreen(
              report: widget.report,
              imageFile: widget.imageFile,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    _scanController.dispose();
    _analysisTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Header with back button
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back, color: cs.onPrimary),
                      style: IconButton.styleFrom(
                        backgroundColor: cs.primary.withOpacity(0.1),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'AI Analysis',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 32),

                // Main content
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Image with scanning overlay
                      Container(
                        width: size.width * 0.8,
                        height: size.width * 0.8 * 0.75,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF0EA5E9),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0EA5E9).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            children: [
                              // Main image
                              Image.file(
                                widget.imageFile,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),

                              // Animated scan line
                              AnimatedBuilder(
                                animation: _scanAnimation,
                                builder: (context, child) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          const Color(
                                            0xFF0EA5E9,
                                          ).withOpacity(0.8),
                                          Colors.transparent,
                                        ],
                                        stops: [
                                          0.0,
                                          0.5 + (_scanAnimation.value * 0.5),
                                          1.0,
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Corner scanning indicators
                              ...List.generate(4, (index) {
                                return Positioned(
                                  top: index < 2 ? 16 : null,
                                  bottom: index >= 2 ? 16 : null,
                                  left: index.isEven ? 16 : null,
                                  right: index.isOdd ? 16 : null,
                                  child: AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      return Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: const Color(0xFF0EA5E9),
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Container(
                                          margin: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0EA5E9),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // AI Brain with pulse animation
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0EA5E9,
                                  ).withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Transform.scale(
                              scale: _pulseAnimation.value,
                              child: const Icon(
                                Icons.smart_toy,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Processing status
                      AnimatedBuilder(
                        animation: _fadeAnimation,
                        builder: (context, child) {
                          return Text(
                            _currentStatus,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: cs.onPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                            textAlign: TextAlign.center,
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // Progress bar
                      Container(
                        width: size.width * 0.8,
                        height: 6,
                        decoration: BoxDecoration(
                          color: cs.onPrimary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _currentProgress,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0EA5E9),
                                      Color(0xFF38BDF8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Progress percentage
                      Text(
                        '${(_currentProgress * 100).toInt()}%',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: cs.onPrimary.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Animated particles/dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return AnimatedBuilder(
                            animation: _mainController,
                            builder: (context, child) {
                              final delay = index * 0.2;
                              final progress = (_mainController.value - delay)
                                  .clamp(0.0, 1.0);
                              final scale = progress > 0
                                  ? (progress * 2).clamp(0.0, 1.0)
                                  : 0.0;

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0EA5E9,
                                  ).withOpacity(scale),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
