import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/attendance_provider.dart';

class CheckOutScreen extends ConsumerStatefulWidget {
  const CheckOutScreen({super.key});

  @override
  ConsumerState<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends ConsumerState<CheckOutScreen> {
  bool _isLoadingGps = true;
  bool _isSubmitting = false;
  Position? _position;
  String? _error;
  String? _successMessage;
  double? _totalHours;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    setState(() { _isLoadingGps = true; _error = null; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() { _error = AppLocalizations.of(context).locationServicesDisabled; _isLoadingGps = false; });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() { _error = AppLocalizations.of(context).locationPermissionDenied; _isLoadingGps = false; });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() { _error = AppLocalizations.of(context).locationPermissionPermanentlyDenied; _isLoadingGps = false; });
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        ).timeout(const Duration(seconds: 10));
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null) {
        setState(() { _position = position; _isLoadingGps = false; });
      } else {
        setState(() { _error = AppLocalizations.of(context).failedToGetLocation; _isLoadingGps = false; });
      }
    } catch (e) {
      setState(() { _error = AppLocalizations.of(context).failedToGetLocation; _isLoadingGps = false; });
    }
  }

  Future<void> _handleCheckOut() async {
    if (_position == null) return;

    setState(() { _isSubmitting = true; _error = null; });
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final result = await repo.checkOut(
        latitude: _position!.latitude,
        longitude: _position!.longitude,
        accuracy: _position!.accuracy,
      );

      setState(() {
        _totalHours = (result['totalHours'] as num?)?.toDouble();
        _successMessage = AppLocalizations.of(context).checkedOut;
        _isSubmitting = false;
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.pop();
    } on DioException catch (e) {
      setState(() { _error = extractErrorMessage(e, AppLocalizations.of(context)); _isSubmitting = false; });
    } catch (e) {
      setState(() { _error = extractErrorMessage(e, AppLocalizations.of(context)); _isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkOut)),
      body: _successMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 80),
                  const SizedBox(height: 16),
                  Text(_successMessage!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_totalHours != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${l10n.totalHours}: ${_totalHours!.toStringAsFixed(1)}h',
                      style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            _isLoadingGps ? Icons.gps_not_fixed : Icons.gps_fixed,
                            color: _position != null ? AppColors.success : AppColors.warning,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isLoadingGps ? l10n.loading : (_position != null ? l10n.gpsReady : _error ?? ''),
                            style: const TextStyle(fontSize: 16),
                          ),
                          if (_position != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${l10n.accuracy}: ${_position!.accuracy.toStringAsFixed(1)}m',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    ),
                  ElevatedButton.icon(
                    onPressed: (_position != null && !_isSubmitting) ? _handleCheckOut : null,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                    icon: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.logout),
                    label: Text(l10n.checkOut),
                  ),
                ],
              ),
            ),
    );
  }
}
