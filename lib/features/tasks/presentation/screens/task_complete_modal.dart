import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

class TaskCompleteModal extends StatefulWidget {
  final bool requirePhoto;
  const TaskCompleteModal({super.key, required this.requirePhoto});

  @override
  State<TaskCompleteModal> createState() => _TaskCompleteModalState();
}

class _TaskCompleteModalState extends State<TaskCompleteModal> {
  final _notesController = TextEditingController();
  final List<String> _photoBase64s = [];
  final _picker = ImagePicker();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (widget.requirePhoto && _photoBase64s.isEmpty) return false;
    return true;
  }

  Future<void> _addPhoto() async {
    final image = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1024, imageQuality: 80);
    if (image == null) return;
    final bytes = await File(image.path).readAsBytes();
    setState(() => _photoBase64s.add(base64Encode(bytes)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.completeTask),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _notesController,
              decoration: InputDecoration(hintText: l10n.completionNotes),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            if (widget.requirePhoto)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.camera_alt, size: 16, color: AppColors.danger),
                    const SizedBox(width: 4),
                    Text(l10n.requiresPhoto, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._photoBase64s.asMap().entries.map((entry) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(entry.value),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      PositionedDirectional(
                        top: 0,
                        end: 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _photoBase64s.removeAt(entry.key)),
                          child: Container(
                            decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                if (_photoBase64s.length < 5)
                  InkWell(
                    onTap: _addPhoto,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo, color: AppColors.textSecondary),
                          Text(l10n.addPhoto, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _canSubmit
              ? () => Navigator.of(context).pop({
                    'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                    'photos': _photoBase64s.isEmpty ? null : _photoBase64s,
                  })
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            minimumSize: const Size(100, 40),
          ),
          child: Text(l10n.submit),
        ),
      ],
    );
  }
}
