import 'package:flutter/material.dart';

enum ActivitySource {
  manual,
  pdfImport;

  static const ActivitySource pdf = ActivitySource.pdfImport;

  static ActivitySource fromString(String? value) {
    if (value == null) return ActivitySource.manual;
    return ActivitySource.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ActivitySource.manual,
    );
  }
}

extension ActivitySourceExtension on ActivitySource {
  String get displayName {
    switch (this) {
      case ActivitySource.manual:
        return 'Manual Entry';
      case ActivitySource.pdfImport:
        return 'Imported from PDF';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivitySource.manual:
        return Icons.edit_note_rounded;
      case ActivitySource.pdfImport:
        return Icons.picture_as_pdf_rounded;
    }
  }
}
