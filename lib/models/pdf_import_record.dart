/// Historical log entry for a completed PDF schedule import.
/// Allows users to audit previously processed documents and review created activities.
class PdfImportRecord {
  final String id;
  final String userId;
  final String filename;
  final int fileSizeBytes;
  final DateTime importDate;
  final int totalDetected;
  final int importedCount;
  final int skippedCount;
  final String status; // 'Imported', 'Partially Imported', 'Cancelled'
  final List<String> activityTitles;

  PdfImportRecord({
    required this.id,
    required this.userId,
    required this.filename,
    required this.fileSizeBytes,
    required this.importDate,
    required this.totalDetected,
    required this.importedCount,
    required this.skippedCount,
    required this.status,
    required this.activityTitles,
  });

  String get fileName => filename;
  DateTime get timestamp => importDate;


  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'filename': filename,
        'fileSizeBytes': fileSizeBytes,
        'importDate': importDate.toIso8601String(),
        'totalDetected': totalDetected,
        'importedCount': importedCount,
        'skippedCount': skippedCount,
        'status': status,
        'activityTitles': activityTitles,
      };

  factory PdfImportRecord.fromJson(Map<String, dynamic> json) {
    return PdfImportRecord(
      id: json['id'] as String,
      userId: json['userId'] as String,
      filename: json['filename'] as String,
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      importDate: DateTime.parse(json['importDate'] as String),
      totalDetected: json['totalDetected'] as int? ?? 0,
      importedCount: json['importedCount'] as int? ?? 0,
      skippedCount: json['skippedCount'] as int? ?? 0,
      status: json['status'] as String? ?? 'Imported',
      activityTitles: (json['activityTitles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
