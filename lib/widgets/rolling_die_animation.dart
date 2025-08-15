// lib/widgets/rolling_die_animation.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/dice_roller_provider.dart';

class RollingDieAnimation extends StatefulWidget {
  const RollingDieAnimation({super.key});

  @override
  State<RollingDieAnimation> createState() => _RollingDieAnimationState();
}

class _RollingDieAnimationState extends State<RollingDieAnimation> {
  WebViewController? _controller;
  bool _isWebViewReady = false;
  bool _isInitialModelLoaded = false;
  bool _isModelReadyForRoll = false;
  String? _currentDieType;
  String? _lastRollId;

  // Map die types to their model asset paths
  final Map<String, String> _dieModelPaths = {
    'd4': 'assets/models/d4.glb',
    'd6': 'assets/models/d6.glb',
    'd8': 'assets/models/d8.glb',
    'd10': 'assets/models/d10.glb',
    'd12': 'assets/models/d12.glb',
    'd20': 'assets/models/d20.glb',
    'd%': 'assets/models/d10_100.glb',
  };

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setOnConsoleMessage((message) {
        debugPrint("[WebViewConsole] ${message.level.name}: ${message.message}");
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => _isWebViewReady = true);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Page resource error: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'DiceModelReady',
        onMessageReceived: (JavaScriptMessage message) {
          if (mounted) {
            setState(() {
              _isModelReadyForRoll = true;
            });
          }
        },
      )
      ..addJavaScriptChannel(
        'DiceRollComplete',
        onMessageReceived: (JavaScriptMessage message) {
          if (mounted) {
            context.read<DiceRollerProvider>().endRolling();
          }
        },
      );

    try {
      final htmlString = await rootBundle.loadString('assets/www/dice_board.html');
      await controller.loadHtmlString(htmlString, baseUrl: null);
    } catch (e) {
      debugPrint("CRITICAL ERROR loading HTML file: $e");
    }

    if (mounted) {
      setState(() {
        _controller = controller;
      });
    }
  }

  void _handleRoll() {
    if (!_isWebViewReady || _controller == null) return;

    final provider = context.read<DiceRollerProvider>();
    if (provider.history.isEmpty) return;

    final latestRoll = provider.history.first;
    final requiredDieType = provider.currentBaseDiceType;

    final currentRollId = latestRoll.hashCode.toString();
    if (_lastRollId == currentRollId && _isModelReadyForRoll) {
      return;
    }

    if (_currentDieType != requiredDieType) {
      _isModelReadyForRoll = false;
      _changeDiceModel(requiredDieType);
      return;
    }

    if (_isModelReadyForRoll) {
      _lastRollId = currentRollId;
      _triggerRoll(latestRoll.individualRolls.first);
    }
  }

  Future<void> _changeDiceModel(String dieType) async {
    if (_controller == null || !_dieModelPaths.containsKey(dieType)) return;

    setState(() {
      _currentDieType = dieType;
      _isModelReadyForRoll = false;
    });

    try {
      final assetPath = _dieModelPaths[dieType]!;
      final byteData = await rootBundle.load(assetPath);
      final buffer = byteData.buffer.asUint8List();
      final modelDataB64 = base64Encode(buffer);

      final functionName = !_isInitialModelLoaded ? 'window.initScene' : 'window.loadNewModel';
      await _controller!.runJavaScript('$functionName("$modelDataB64");');

      if (!_isInitialModelLoaded) {
        setState(() {
          _isInitialModelLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("CRITICAL ERROR loading dice model into WebView: $e");
    }
  }

  void _triggerRoll(int finalResult) {
    if (_controller == null) return;

    final rollData = jsonEncode({'result': finalResult});
    _controller!.runJavaScript('window.rollDie(\'$rollData\');');

    setState(() {
      _isModelReadyForRoll = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_isWebViewReady) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Consumer<DiceRollerProvider>(
      builder: (context, provider, child) {
        if (provider.isRolling) {
          _handleRoll();
        }
        return child!;
      },
      child: SizedBox(
        height: 150,
        child: AbsorbPointer(child: WebViewWidget(controller: _controller!)),
      ),
    );
  }
}
