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
  bool _isModelReadyForRoll = false; // This is our new flag
  String? _lastRollId;

  @override
  void initState() {
    super.initState();
    debugPrint("[RDA] ------------------ INIT STATE ------------------");
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    debugPrint("[RDA] 1. Initializing WebView Controller...");
    final controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.transparent)
          ..setOnConsoleMessage((message) {
            debugPrint(
              "[WebViewConsole] ${message.level.name}: ${message.message}",
            );
          })
          // --- THIS IS THE KEY CHANGE ---
          // We are now using a NavigationDelegate to know when the page is ready.
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (String url) {
                debugPrint(
                  "[RDA] 3. Page Finished Loading. Triggering model load...",
                );
                // Now that the page is loaded, we can safely call our JS functions.
                _loadDiceModel();
              },
              onWebResourceError: (WebResourceError error) {
                debugPrint('''
              Page resource error:
              code: ${error.errorCode}
              description: ${error.description}
              errorType: ${error.errorType}
              isForMainFrame: ${error.isForMainFrame}
            ''');
              },
            ),
          )
          // -----------------------------
          ..addJavaScriptChannel(
            'DiceModelReady', // This channel is now used correctly as a "ready for roll" signal
            onMessageReceived: (JavaScriptMessage message) {
              debugPrint(
                "[RDA] 6. JS Channel 'DiceModelReady' received: ${message.message}",
              );
              // The model is fully loaded in the WebView, we are ready to roll.
              setState(() {
                _isModelReadyForRoll = true;
              });
            },
          )
          ..addJavaScriptChannel(
            'DiceRollComplete',
            onMessageReceived: (JavaScriptMessage message) {
              debugPrint(
                "[RDA] 9. JS Channel 'DiceRollComplete' received: ${message.message}",
              );
            },
          );

    try {
      debugPrint("[RDA] 2. Loading HTML file from assets...");
      final htmlString = await rootBundle.loadString(
        'assets/www/dice_board.html',
      );
      await controller.loadHtmlString(htmlString, baseUrl: null);
    } catch (e) {
      debugPrint("[RDA] CRITICAL ERROR loading HTML file: $e");
    }

    setState(() {
      _controller = controller;
    });
  }

  Future<void> _loadDiceModel() async {
    if (_controller == null) {
      debugPrint("[RDA] ERROR: _loadDiceModel called but controller is null.");
      return;
    }
    debugPrint("[RDA] 4. Loading d20.glb model into memory...");

    try {
      final byteData = await rootBundle.load('assets/models/d20.glb');
      final buffer = byteData.buffer.asUint8List();
      final modelDataB64 = base64Encode(buffer);
      debugPrint(
        "[RDA] 5. Model loaded and encoded. Sending to 'initScene' in WebView...",
      );

      await _controller!.runJavaScript('window.initScene("$modelDataB64");');
    } catch (e) {
      debugPrint("[RDA] CRITICAL ERROR loading dice model into WebView: $e");
    }
  }

  void _triggerRoll() {
    // We now check if the model is ready for a roll.
    if (_controller == null || !_isModelReadyForRoll) {
      debugPrint(
        "[RDA] SKIPPING ROLL: Controller not ready (${_controller != null}) or model not ready for roll (${_isModelReadyForRoll}).",
      );
      return;
    }
    debugPrint("[RDA] 7. _triggerRoll called.");
    final provider = context.read<DiceRollerProvider>();
    if (provider.history.isEmpty) {
      debugPrint("[RDA] SKIPPING ROLL: History is empty.");
      return;
    }
    final latestRoll = provider.history.first;
    final finalResult = latestRoll.individualRolls.first;

    final currentRollId = latestRoll.hashCode.toString();
    if (_lastRollId == currentRollId) {
      return; // Silently skip if we already processed this roll
    }
    _lastRollId = currentRollId;

    final rollData = jsonEncode({'result': finalResult});
    debugPrint("[RDA] 8. Sending roll data to JS: $rollData");

    _controller!.runJavaScript('window.rollDie(\'$rollData\');');
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Consumer<DiceRollerProvider>(
      builder: (context, provider, child) {
        if (provider.isRolling) {
          _triggerRoll();
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
