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

  DiceRollerProvider? _diceRollerProvider;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // We listen to the provider here, which is safer than in initState.
    // This method is called when the widget is first built and whenever its
    // dependencies change.
    final newProvider = Provider.of<DiceRollerProvider>(context);
    if (_diceRollerProvider != newProvider) {
      _diceRollerProvider?.removeListener(_onProviderChange);
      _diceRollerProvider = newProvider;
      _diceRollerProvider?.addListener(_onProviderChange);
    }
  }

  @override
  void dispose() {
    _diceRollerProvider?.removeListener(_onProviderChange);
    super.dispose();
  }

  void _onProviderChange() {
    // This method is now called outside of the build cycle.
    // It's safe to call methods that might trigger setState here.
    if (_diceRollerProvider?.isRolling ?? false) {
      _handleRoll();
    }
  }

  Future<void> _initializeWebView() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color.fromARGB(1, 0, 0, 0)) // Workaround for transparency
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
            // After the model is ready, we might need to immediately trigger the roll
            // if a roll was requested while the model was loading.
            _handleRoll();
          }
        },
      )
      ..addJavaScriptChannel(
        'DiceRollComplete',
        onMessageReceived: (JavaScriptMessage message) {
          if (mounted) {
            _diceRollerProvider?.endRolling();
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
    if (!_isWebViewReady || _controller == null || _diceRollerProvider == null) return;

    final provider = _diceRollerProvider!;
    if (provider.history.isEmpty) return;

    final latestRoll = provider.history.first;
    final requiredDieType = provider.currentBaseDiceType;

    final currentRollId = latestRoll.hashCode.toString();
    // If we've already processed this roll, don't do it again.
    if (_lastRollId == currentRollId) {
      return;
    }

    if (_currentDieType != requiredDieType) {
      // Don't set a "in progress" flag, just let the state (_isModelReadyForRoll)
      // handle it. If we get here, a model change is needed.
      _changeDiceModel(requiredDieType);
      return; // Exit and wait for DiceModelReady to call _handleRoll again.
    }

    if (_isModelReadyForRoll) {
      setState(() {
        _lastRollId = currentRollId;
      });
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

    // Set model as not-ready for the *next* roll.
    // This prevents re-triggering the same roll if the provider updates again.
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

    return SizedBox(
      height: 150,
      child: AbsorbPointer(child: WebViewWidget(controller: _controller!)),
    );
  }
}
