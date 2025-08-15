// lib/screens/dice_roller_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

// --- CORRECTED IMPORTS ---
import '../providers/dice_roller_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/rolling_die_animation.dart';
import '../models/roll_entry.dart'; // We need this for the history dialog
// -------------------------

class DiceRollerScreen extends StatefulWidget {
  const DiceRollerScreen({super.key});

  @override
  State<DiceRollerScreen> createState() => _DiceRollerScreenState();
}

class _DiceRollerScreenState extends State<DiceRollerScreen> {
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  bool _adsSupported = false;

  final String _androidTestBannerId = 'ca-app-pub-3940256099942544/6300978111';
  final String _iosTestBannerId = 'ca-app-pub-3940256099942544/2934735716';
  String _bannerAdUnitId = '';

  final TextEditingController _numDiceController = TextEditingController();
  final TextEditingController _modifierController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _adsSupported = true;
      _bannerAdUnitId =
          Platform.isAndroid ? _androidTestBannerId : _iosTestBannerId;
    } else {
      _adsSupported = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DiceRollerProvider>();
      _numDiceController.text = provider.numberOfDice.toString();
      _modifierController.text = provider.modifier.toString();

      _numDiceController.addListener(() {
        final dProvider = context.read<DiceRollerProvider>();
        final String text = _numDiceController.text;
        final count = int.tryParse(text);
        if (count != null && count != dProvider.numberOfDice) {
          dProvider.setNumberOfDice(count);
        }
      });

      _modifierController.addListener(() {
        final dProvider = context.read<DiceRollerProvider>();
        final String text = _modifierController.text;
        final mod = int.tryParse(text);
        if (mod != null && mod != dProvider.modifier) {
          dProvider.setModifier(mod);
        }
      });

      context.read<DiceRollerProvider>().addListener(
        _updateTextFieldsFromProvider,
      );

      if (_adsSupported) {
        final adsRemoved = context.read<DiceRollerProvider>().adsRemoved;
        if (!adsRemoved) _loadBannerAd();
      }
    });
  }

  void _updateTextFieldsFromProvider() {
    if (!mounted) return;
    final provider = context.read<DiceRollerProvider>();

    if (_numDiceController.text != provider.numberOfDice.toString()) {
      _numDiceController.text = provider.numberOfDice.toString();
    }
    if (_modifierController.text != provider.modifier.toString()) {
      _modifierController.text = provider.modifier.toString();
    }
  }

  @override
  void dispose() {
    context.read<DiceRollerProvider>().removeListener(
      _updateTextFieldsFromProvider,
    );
    _bannerAd?.dispose();
    _numDiceController.dispose();
    _modifierController.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    if (!_adsSupported || _bannerAdUnitId.isEmpty) return;
    final adsRemoved = context.read<DiceRollerProvider>().adsRemoved;
    if (adsRemoved) return;

    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isBannerAdLoaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  Widget _buildDieButton(int sides, String label, DiceRollerProvider provider) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: theme.colorScheme.onPrimary.withOpacity(0.5),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          provider.rollDice(sides, label);
        },
        child: Text(label),
      ),
    );
  }

  Widget _buildCounterField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    bool isModifier = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton.outlined(
                icon: const Icon(Icons.remove),
                padding: EdgeInsets.zero,
                tooltip: 'Decrement $label',
                onPressed: onDecrement,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              height: 40,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.numberWithOptions(
                  signed: isModifier,
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                ],
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton.outlined(
                icon: const Icon(Icons.add),
                padding: EdgeInsets.zero,
                tooltip: 'Increment $label',
                onPressed: onIncrement,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final diceProvider = context.watch<DiceRollerProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final latestRoll =
        diceProvider.history.isNotEmpty ? diceProvider.history.first : null;
    final isCurrentlyDark = Theme.of(context).brightness == Brightness.dark;

    // Thematic colors for critical success/fumble
    final critSuccessColor =
        isCurrentlyDark ? Colors.green.shade300 : const Color(0xFF2E7D32);
    final critFumbleColor =
        isCurrentlyDark ? Colors.red.shade300 : const Color(0xFFC62828);
    final critSuccessBg =
        isCurrentlyDark ? Colors.green.withOpacity(0.1) : Colors.green.shade50;
    final critFumbleBg =
        isCurrentlyDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50;

    return Scaffold(
      extendBodyBehindAppBar:
          true, // Allows body to go behind transparent AppBar
      appBar: AppBar(
        title: Text(
          'D&D Dice Roller',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        actions: [
          IconButton(
            icon: Icon(themeProvider.themeIcon),
            tooltip: themeProvider.themeTooltip,
            onPressed: () => context.read<ThemeProvider>().cycleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Configuration',
            onPressed:
                () => context.read<DiceRollerProvider>().resetConfiguration(),
          ),
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'Show History',
            onPressed: () => _showHistoryDialog(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // --- BACKGROUND TEXTURE ---
          // Make sure you have an image at 'assets/images/parchment_background.jpg'
          // or change the path to your own image.
          Positioned.fill(
            child: Image.asset(
              isCurrentlyDark
                  ? 'assets/images/dark_background.jpg' // Example for dark theme
                  : 'assets/images/background.jpg', // Example for light theme
              fit: BoxFit.cover,
              color: isCurrentlyDark ? Colors.black.withOpacity(0.3) : null,
              colorBlendMode: isCurrentlyDark ? BlendMode.darken : null,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 16), // Space below AppBar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCounterField(
                        label: "Dice",
                        controller: _numDiceController,
                        onDecrement:
                            () => context
                                .read<DiceRollerProvider>()
                                .setNumberOfDice(diceProvider.numberOfDice - 1),
                        onIncrement:
                            () => context
                                .read<DiceRollerProvider>()
                                .setNumberOfDice(diceProvider.numberOfDice + 1),
                      ),
                      _buildCounterField(
                        label: "Modifier",
                        controller: _modifierController,
                        isModifier: true,
                        onDecrement:
                            () => context
                                .read<DiceRollerProvider>()
                                .setModifier(diceProvider.modifier - 1),
                        onIncrement:
                            () => context
                                .read<DiceRollerProvider>()
                                .setModifier(diceProvider.modifier + 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (diceProvider.numberOfDice == 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilterChip(
                          label: const Text('Advantage'),
                          selected: diceProvider.isAdvantage,
                          onSelected:
                              (_) =>
                                  context
                                      .read<DiceRollerProvider>()
                                      .toggleAdvantage(),
                        ),
                        const SizedBox(width: 10),
                        FilterChip(
                          label: const Text('Disadvantage'),
                          selected: diceProvider.isDisadvantage,
                          onSelected:
                              (_) =>
                                  context
                                      .read<DiceRollerProvider>()
                                      .toggleDisadvantage(),
                        ),
                      ],
                    ),
                  if (diceProvider.numberOfDice == 1)
                    const SizedBox(height: 10),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        _buildDieButton(4, 'd4', diceProvider),
                        _buildDieButton(6, 'd6', diceProvider),
                        _buildDieButton(8, 'd8', diceProvider),
                        _buildDieButton(10, 'd10', diceProvider),
                        _buildDieButton(12, 'd12', diceProvider),
                        _buildDieButton(20, 'd20', diceProvider),
                        _buildDieButton(100, 'd%', diceProvider),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- UPDATED WIDGET CALL ---
                  if (diceProvider.isRolling && latestRoll != null)
                    const RollingDieAnimation()
                  else if (latestRoll != null)
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.2),
                        ),
                      ),
                      color:
                          latestRoll.isCriticalSuccess
                              ? critSuccessBg
                              : (latestRoll.isCriticalFumble
                                  ? critFumbleBg
                                  : null),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Text(
                              'Latest: ${latestRoll.description}'
                              '${latestRoll.wasAdvantage ? " (Adv)" : ""}'
                              '${latestRoll.wasDisadvantage ? " (Dis)" : ""}'
                              ' ${latestRoll.modifierValue >= 0 ? "+" : ""}${latestRoll.modifierValue}',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${latestRoll.totalResult}',
                              style: Theme.of(
                                context,
                              ).textTheme.displayMedium?.copyWith(
                                color:
                                    latestRoll.isCriticalSuccess
                                        ? critSuccessColor
                                        : (latestRoll.isCriticalFumble
                                            ? critFumbleColor
                                            : null),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                "Roll: ${latestRoll.individualRolls.join(', ')}"
                                "${latestRoll.advDisRawRolls != null ? ' from [${latestRoll.advDisRawRolls!.join(', ')}]' : ''}",
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // Adjusted height to match the new animation's height
                    SizedBox(
                      height: 150,
                      child: Center(
                        child: Text(
                          "Roll some dice!",
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),

                  const Spacer(),
                  if (_adsSupported && _isBannerAdLoaded && _bannerAd != null)
                    SizedBox(
                      width: _bannerAd!.size.width.toDouble(),
                      height: _bannerAd!.size.height.toDouble(),
                      child: AdWidget(ad: _bannerAd!),
                    )
                  else
                    const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog(BuildContext context) {
    // ... (This method remains unchanged and works as expected)
    showDialog(
      context: context,
      builder: (dialogContext) {
        final history = dialogContext.watch<DiceRollerProvider>().history;
        final isDialogDark =
            Theme.of(dialogContext).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.background,
          title: Text(
            'Roll History',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child:
                history.isEmpty
                    ? const Center(child: Text('No rolls yet.'))
                    : ListView.builder(
                      shrinkWrap: true,
                      itemCount: history.length,
                      itemBuilder: (_, index) {
                        final RollEntry entry = history[index];
                        return ListTile(
                          title: Text(
                            entry.toString(),
                            style: TextStyle(
                              color:
                                  entry.isCriticalSuccess
                                      ? (isDialogDark
                                          ? Colors.green.shade300
                                          : Colors.green.shade700)
                                      : (entry.isCriticalFumble
                                          ? (isDialogDark
                                              ? Colors.red.shade300
                                              : Colors.red.shade700)
                                          : null),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          actions: <Widget>[
            if (history.isNotEmpty)
              TextButton(
                child: const Text('Clear History'),
                onPressed: () {
                  dialogContext.read<DiceRollerProvider>().clearHistory();
                },
              ),
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }
}
