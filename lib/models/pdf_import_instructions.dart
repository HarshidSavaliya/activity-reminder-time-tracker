/// User instruction parameters configured in Step 2 of the PDF import flow.
/// Guides the parser on which fields to capture, what categories to prioritize,
/// and applies custom natural language filtering.
class PdfImportInstructions {
  bool readSubjectName;
  bool readDate;
  bool readStartTime;
  bool readEndTime;
  bool readFaculty;
  bool readClassroom;
  bool readExam;
  bool readAssignment;
  bool readDepartment;
  bool readSemester;
  String customInstruction;

  PdfImportInstructions({
    this.readSubjectName = true,
    this.readDate = true,
    this.readStartTime = true,
    this.readEndTime = true,
    this.readFaculty = true,
    this.readClassroom = true,
    this.readExam = false,
    this.readAssignment = false,
    this.readDepartment = false,
    this.readSemester = false,
    this.customInstruction = '',
  });

  // Convenience getters/setters for wizard steps
  bool get extractClasses => readSubjectName;
  set extractClasses(bool v) => readSubjectName = v;

  bool get extractLabs => readClassroom;
  set extractLabs(bool v) => readClassroom = v;

  bool get extractExams => readExam;
  set extractExams(bool v) => readExam = v;

  PdfImportInstructions copyWith({
    bool? readSubjectName,
    bool? readDate,
    bool? readStartTime,
    bool? readEndTime,
    bool? readFaculty,
    bool? readClassroom,
    bool? readExam,
    bool? readAssignment,
    bool? readDepartment,
    bool? readSemester,
    String? customInstruction,
  }) {
    return PdfImportInstructions(
      readSubjectName: readSubjectName ?? this.readSubjectName,
      readDate: readDate ?? this.readDate,
      readStartTime: readStartTime ?? this.readStartTime,
      readEndTime: readEndTime ?? this.readEndTime,
      readFaculty: readFaculty ?? this.readFaculty,
      readClassroom: readClassroom ?? this.readClassroom,
      readExam: readExam ?? this.readExam,
      readAssignment: readAssignment ?? this.readAssignment,
      readDepartment: readDepartment ?? this.readDepartment,
      readSemester: readSemester ?? this.readSemester,
      customInstruction: customInstruction ?? this.customInstruction,
    );
  }

  PdfImportInstructions clone() {
    return copyWith();
  }
}
