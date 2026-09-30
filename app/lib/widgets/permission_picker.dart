import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Permesso di chi riceve una lista (o tutte le liste): "Solo lettura" oppure "Lettura e modifica".
/// Usato alla creazione della lista, nella condivisione di una lista e in quella di tutte le liste.
class PermissionPicker extends StatelessWidget {
  const PermissionPicker({super.key, required this.canEdit, required this.onChanged});

  final bool canEdit;

  /// null = non modificabile (mentre si salva).
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Occupa lo spazio disponibile e accorcia il testo se serve: le righe delle persone sono strette.
    return DropdownButton<bool>(
      value: canEdit,
      isDense: true,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(16),
      onChanged: onChanged == null ? null : (v) => onChanged!(v ?? canEdit),
      items: [
        DropdownMenuItem(
          value: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility_outlined, size: 18),
              const SizedBox(width: 6),
              Flexible(child: Text(l.permissionRead, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        DropdownMenuItem(
          value: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_outlined, size: 18),
              const SizedBox(width: 6),
              Flexible(child: Text(l.permissionReadWrite, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ],
    );
  }
}
