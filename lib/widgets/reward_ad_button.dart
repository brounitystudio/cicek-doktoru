import 'package:flutter/material.dart';

import '../services/ad_service.dart';
import '../services/language_service.dart';

class RewardAdButton extends StatefulWidget {
  const RewardAdButton({super.key, required this.onRewardGranted});

  final ValueChanged<int> onRewardGranted;

  @override
  State<RewardAdButton> createState() => _RewardAdButtonState();
}

class _RewardAdButtonState extends State<RewardAdButton> {
  bool _loading = false;

  Future<void> _watchAd() async {
    setState(() => _loading = true);
    try {
      final credits = await AdService.instance.showRewardedForDiagnosisCredit();
      if (!mounted) {
        return;
      }
      widget.onRewardGranted(credits);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AdException
                ? error.message
                : context.tr(
                    'Reklam şu an hazır değil, birazdan tekrar dene.',
                    'The ad is not ready right now. Please try again shortly.',
                  ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _loading ? null : _watchAd,
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_circle_outline),
      label: Text(
        context.tr(
          'Reklam izle, +1 analiz hakkı al',
          'Watch ad, get +1 analysis',
        ),
      ),
    );
  }
}
