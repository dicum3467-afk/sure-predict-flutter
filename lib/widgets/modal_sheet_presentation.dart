import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

Future<void> showModalSheet(
  BuildContext context, {
  required Widget content,
  bool dragEnabled = true,
}) async {
  await showMaterialModalBottomSheet(
    context: context,
    expand: false,
    enableDrag: dragEnabled,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Material(
          child: content,
        ),
      ),
    ),
  );
}
