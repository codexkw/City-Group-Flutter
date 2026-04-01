import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
  int? _autoSelectedLocationId;
  String? _autoSelectedLocationName;
  File? _selfieFile;
  String? _selfieBase64;

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
        _autoSelectNearestLocation(position);
      } else {
        setState(() { _error = AppLocalizations.of(context).failedToGetLocation; _isLoadingGps = false; });
      }
    } catch (e) {
      setState(() { _error = AppLocalizations.of(context).failedToGetLocation; _isLoadingGps = false; });
    }
  }

  void _autoSelectNearestLocation(Position position) {
    final locationsAsync = ref.read(locationsProvider);
    locationsAsync.whenData((locations) {
      if (locations.isEmpty) return;

      double minDistance = double.infinity;
      int? nearestId;
      String? nearestName;

      for (final loc in locations) {
        final lat = (loc['latitude'] as num?)?.toDouble();
        final lng = (loc['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final distance = _calculateDistance(position.latitude, position.longitude, lat, lng);
        if (distance < minDistance) {
          minDistance = distance;
          nearestId = loc['id'] as int?;
          nearestName = loc['nameEn'] as String?;
        }
      }

      if (nearestId != null) {
        setState(() {
          _autoSelectedLocationId = nearestId;
          _autoSelectedLocationName = nearestName;
        });
      }
    });
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // pi / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // meters
  }

  Future<void> _takeSelfie() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (photo != null) {
      final file = File(photo.path);
      final bytes = await file.readAsBytes();
      setState(() {
        _selfieFile = file;
        _selfieBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _handleCheckIn() async {
    if (_position == null) return;

    setState(() { _isSubmitting = true; _error = null; });
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final result = await repo.checkIn(
        locationId: _autoSelectedLocationId,
        latitude: _position!.latitude,
        longitude: _position!.longitude,
        accuracy: _position!.accuracy,
        photoBase64: _selfieBase64,
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
      String errorMsg;
      switch (code) {
        case 'ALREADY_CHECKED_IN':
          errorMsg = l10n.alreadyCheckedIn;
          break;
        case 'GPS_ACCURACY_LOW':
          errorMsg = l10n.gpsAccuracyLow;
          break;
        default:
          errorMsg = extractErrorMessage(e, l10n);
      }
      setState(() { _error = errorMsg; _isSubmitting = false; });
    } catch (e) {
      setState(() { _error = extractErrorMessage(e, AppLocalizations.of(context)); _isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Watch locations to trigger auto-select when data arrives
    final locationsAsync = ref.watch(locationsProvider);

    // Re-trigger auto-select when locations data arrives and we have position
    locationsAsync.whenData((_) {
      if (_position != null && _autoSelectedLocationId == null) {
        _autoSelectNearestLocation(_position!);
      }
    });

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
          : SingleChildScrollView(
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
                                else if (_position != null) ...[
                                  Text(
                                    '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}\n${l10n.accuracy}: ${_position!.accuracy.toStringAsFixed(1)}m',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                  if (_autoSelectedLocationName != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            _autoSelectedLocationName!,
                                            style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                ] else
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

                  // Selfie Photo
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (_selfieFile != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_selfieFile!, height: 200, width: double.infinity, fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _takeSelfie,
                              icon: const Icon(Icons.camera_alt),
                              label: Text(l10n.retakePhoto),
                            ),
                          ] else ...[
                            Icon(Icons.camera_alt, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text(l10n.photoInstructions, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _takeSelfie,
                              icon: const Icon(Icons.camera_alt),
                              label: Text(l10n.takeSelfie),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

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
                    onPressed: (_position != null && !_isSubmitting)
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
