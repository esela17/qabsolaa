import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String? id;
  final String studentUsername;
  final String studentName;
  final String attendedGroup;
  final Timestamp timestamp;
  final String attendanceDate;
  final bool isDelayed;
  final bool noHomework;
  final double? examGrade; // <--- حقل جديد: درجة الامتحان (يمكن أن يكون null إذا لم يتم إدخالها)

  AttendanceRecord({
    this.id,
    required this.studentUsername,
    required this.studentName,
    required this.attendedGroup,
    required this.timestamp,
    required this.attendanceDate,
    this.isDelayed = false,
    this.noHomework = false,
    this.examGrade, // <--- حقل جديد (اختياري)
  });

  Map<String, dynamic> toMap() {
    return {
      'studentUsername': studentUsername,
      'studentName': studentName,
      'attendedGroup': attendedGroup,
      'timestamp': timestamp,
      'attendanceDate': attendanceDate,
      'isDelayed': isDelayed,
      'noHomework': noHomework,
      'examGrade': examGrade, // <--- إضافة الحقل
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map, {String? id}) {
    return AttendanceRecord(
      id: id,
      studentUsername: map['studentUsername'] as String,
      studentName: map['studentName'] as String,
      attendedGroup: map['attendedGroup'] as String,
      timestamp: map['timestamp'] as Timestamp,
      attendanceDate: map['attendanceDate'] as String,
      isDelayed: map['isDelayed'] as bool? ?? false,
      noHomework: map['noHomework'] as bool? ?? false,
      examGrade: map['examGrade'] as double?, // <--- قراءة الحقل
    );
  }

  factory AttendanceRecord.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceRecord.fromMap(data, id: doc.id);
  }

  AttendanceRecord copyWith({
    String? id,
    String? studentUsername,
    String? studentName,
    String? attendedGroup,
    Timestamp? timestamp,
    String? attendanceDate,
    bool? isDelayed,
    bool? noHomework,
    double? examGrade, // <--- إضافة الحقل إلى copyWith
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      studentUsername: studentUsername ?? this.studentUsername,
      studentName: studentName ?? this.studentName,
      attendedGroup: attendedGroup ?? this.attendedGroup,
      timestamp: timestamp ?? this.timestamp,
      attendanceDate: attendanceDate ?? this.attendanceDate,
      isDelayed: isDelayed ?? this.isDelayed,
      noHomework: noHomework ?? this.noHomework,
      examGrade: examGrade ?? this.examGrade, // <--- تحديث الحقل
    );
  }
}