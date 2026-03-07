import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/attendance_provider.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  Position? _position;
  bool _isLoadingGps = true;
  bool _isSubmitting = false;
  String? _error;
  String? _successMessage;
  int? _selectedLocationId;

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

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() { _position = position; _isLoadingGps = false; });
    } catch (e) {
      setState(() { _error = AppLocalizations.of(context).failedToGetLocation; _isLoadingGps = false; });
    }
  }

  Future<void> _handleCheckIn() async {
    if (_position == null || _selectedLocationId == null) return;

    setState(() { _isSubmitting = true; _error = null; });
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final result = await repo.checkIn(
        locationId: _selectedLocationId!,
        latitude: _position!.latitude,
        longitude: _position!.longitude,
        accuracy: _position!.accuracy,
      );

      final status = result['status'] ?? '';
      setState(() {
        _successMessage = '${AppLocalizations.of(context).checkedIn} - $status';
        _isSubmitting = false;
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.pop();
    } on DioException catch (e) {
      final code = extractErrorCode(e);
      final l10n = AppLocalizations.of(context);
      setState(() {
        _error = code == 'OUTSIDE_GEOFENCE'
            ? l10n.outsideGeofence
            : extractErrorMessage(e, l10n);
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() { _error = extractErrorMessage(e, AppLocalizations.of(context)); _isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locationsAsync = ref.watch(locationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkIn)),
      body: _successMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 80),
                  const SizedBox(height: 16),
                  Text(_successMessage!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // GPS Status Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            _isLoadingGps ? Icons.gps_not_fixed : (_position != null ? Icons.gps_fixed : Icons.gps_off),
                            color: _position != null ? AppColors.success : AppColors.warning,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.location, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                if (_isLoadingGps)
                                  Text(l10n.loading, style: const TextStyle(color: AppColors.textSecondary))
                                else if (_position != null)
                                  Text(
                                    '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}\nAccuracy: ${_position!.accuracy.toStringAsFixed(1)}m',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  )
                                else
                                  Text(_error ?? l10n.gpsUnavailable, style: const TextStyle(color: AppColors.danger)),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.refresh), onPressed: _getLocation),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location selector
                  Text(l10n.location, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  locationsAsync.when(
                    data: (locations) {
                      if (locations.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(l10n.noData),
                          ),
                        );
                      }
                      return Column(
                        children: locations.map((loc) {
                          final id = loc['id'];
                          final isSelected = _selectedLocationId == id;
                          return Card(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.location_on, color: AppColors.primary),
                              title: Text(loc['nameEn'] ?? ''),
                              subtitle: Text('${loc['address'] ?? ''}\n${l10n.radius}: ${loc['geofenceRadius']}m'),
                              trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                              onTap: () => setState(() => _selectedLocationId = id),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text(l10n.errorOccurred, style: const TextStyle(color: AppColors.danger)),
                  ),

                  const Spacer(),

                  // Error
                  if (_error != null && _position != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    ),

                  // Check In button
                  ElevatedButton.icon(
                    onPressed: (_position != null && _selectedLocationId != null && !_isSubmitting)
                        ? _handleCheckIn
                        : null,
                    icon: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.login),
                    label: Text(l10n.checkIn),
                  ),
                ],
              ),
            ),
    );
  }
}
