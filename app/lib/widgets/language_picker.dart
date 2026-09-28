import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../state/locale_controller.dart';

/// Nome della lingua in uso, es. "Italiano" oppure "Come il telefono (English)".
String languageLabel(BuildContext context, LocaleController controller) {
  final name = appLanguages[controller.language]!;
  return controller.choice == null ? context.l10n.languageSystem(name) : name;
}

/// Scelta della lingua: come il telefono oppure una delle lingue dell'app (ognuna scritta nella propria lingua).
Future<void> chooseLanguage(BuildContext context) async {
  final controller = context.read<LocaleController>();
  // '' = come il telefono (il valore null chiuderebbe il dialogo senza scelta).
  final value = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(context.l10n.language),
      children: [
        RadioGroup<String>(
          groupValue: controller.choice ?? '',
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(
            children: [
              RadioListTile<String>(
                value: '',
                title: Text(context.l10n.languageSystem(appLanguages[LocaleController.systemLanguage()]!)),
              ),
              for (final entry in appLanguages.entries)
                RadioListTile<String>(value: entry.key, title: Text(entry.value)),
            ],
          ),
        ),
      ],
    ),
  );
  if (value != null) await controller.setChoice(value.isEmpty ? null : value);
}

/// Riga "Lingua" della schermata di accesso.
class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LocaleController>();
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(context.l10n.language),
      subtitle: Text(languageLabel(context, controller)),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => chooseLanguage(context),
    );
  }
}
