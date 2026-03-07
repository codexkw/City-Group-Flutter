import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../services/background_speed_service.dart';

/// A persistent top banner that appears when a speed violation is detected.
/// Auto-dismisses when speed drops below the limit.
class SpeedAlertBanner extends StatefulWidget {
  final Widget child;
  const SpeedAlertBanner({super.key, required this.child});

  @override
  State<SpeedAlertBanner> createState() => _SpeedAlertBannerState();
}

class _SpeedAlertBannerState extends State<SpeedAlertBanner> {
  bool _isViolating = false;
  double _currentSpeed = 0;
  double _speedLimit = 120;
  StreamSubscription<Map<String, dynamic>?>? _violationSub;
  StreamSubscription<Map<String, dynamic>?>? _speedSub;

  @override
  void initState() {
    super.initState();
    _violationSub = BackgroundSpeedService.violationStream.listen((data) {
      if (data != null && mounted) {
        setState(() {
          _isViolating = true;
          _currentSpeed = (data['speedKmh'] as num?)?.toDouble() ?? 0;
          _speedLimit = (data['speedLimit'] as num?)?.toDouble() ?? 120;
        });
      }
    });

    _speedSub = BackgroundSpeedService.speedStream.listen((data) {
      if (data != null && mounted) {
        final speed = (data['speedKmh'] as num?)?.toDouble() ?? 0;
        if (speed <= _speedLimit && _isViolating) {
          setState(() => _isViolating = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _violationSub?.cancel();
    _speedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        if (_isViolating)
          MaterialBanner(
            backgroundColor: AppColors.danger,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            content: Row(
              children: [
                const Icon(Icons.speed, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.speedViolation,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        '${_currentSpeed.toStringAsFixed(0)} ${l10n.speedUnit} (${l10n.speedLimit}: ${_speedLimit.toStringAsFixed(0)} ${l10n.speedUnit})',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: const [SizedBox.shrink()],
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
