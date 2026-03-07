import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LanguageTile(
            title: l10n.english,
            subtitle: 'English',
            isSelected: currentLocale?.languageCode == 'en',
            onTap: () => ref.read(authStateProvider.notifier).updateLocale('en'),
          ),
          const SizedBox(height: 8),
          _LanguageTile(
            title: l10n.arabic,
            subtitle: 'Arabic',
            isSelected: currentLocale?.languageCode == 'ar',
            onTap: () => ref.read(authStateProvider.notifier).updateLocale('ar'),
          ),
          const SizedBox(height: 8),
          _LanguageTile(
            title: l10n.hindi,
            subtitle: 'Hindi',
            isSelected: currentLocale?.languageCode == 'hi',
            onTap: () => ref.read(authStateProvider.notifier).updateLocale('hi'),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        title: Text(title, style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        )),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: AppColors.primary)
            : null,
        onTap: onTap,
      ),
    );
  }
}
