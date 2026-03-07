import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

class PauseReasonBottomSheet extends StatefulWidget {
  const PauseReasonBottomSheet({super.key});

  @override
  State<PauseReasonBottomSheet> createState() => _PauseReasonBottomSheetState();
}

class _PauseReasonBottomSheetState extends State<PauseReasonBottomSheet> {
  String? _selectedReason;
  final _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  bool get _canConfirm {
    if (_selectedReason == null) return false;
    if (_selectedReason == 'Other' && _otherController.text.trim().isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final reasons = <String, String>{
      'Break': l10n.reasonBreak,
      'WaitingForEquipment': l10n.reasonWaitingEquipment,
      'WaitingForAccess': l10n.reasonWaitingAccess,
      'Emergency': l10n.reasonEmergency,
      'CustomerNotAvailable': l10n.reasonCustomerNotAvailable,
      'Other': l10n.reasonOther,
    };

    return PopScope(
      canPop: false,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: 16,
          end: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.pauseReason,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.pauseReasonRequired, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ...reasons.entries.map((entry) {
              final isSelected = _selectedReason == entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedReason = entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? AppColors.primary : AppColors.textHint,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(entry.value, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (_selectedReason == 'Other') ...[
              const SizedBox(height: 4),
              TextField(
                controller: _otherController,
                decoration: InputDecoration(hintText: l10n.reasonOtherPlaceholder),
                maxLines: 2,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _canConfirm
                  ? () => Navigator.of(context).pop({
                        'pauseReason': _selectedReason!,
                        if (_selectedReason == 'Other') 'pauseReasonText': _otherController.text.trim(),
                      })
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
              icon: const Icon(Icons.pause),
              label: Text(l10n.confirmPause),
            ),
          ],
        ),
      ),
    );
  }
}
