import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String username;
  final String studentName;
  final String studentPhone;
  final String parentPhone;
  final String academicYear;
  final List<String> groupNames;
  final Map<String, dynamic> grades;
  final String qrCodeData;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  Student({
    required this.username,
    required this.studentName,
    required this.studentPhone,
    required this.parentPhone,
    required this.academicYear,
    required this.groupNames,
    required this.grades,
    required this.qrCodeData,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'studentName': studentName,
      'studentPhone': studentPhone,
      'parentPhone': parentPhone,
      'academicYear': academicYear,
      'groupNames': groupNames,
      'grades': grades,
      'qrCodeData': qrCodeData,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      username: map['username'] as String,
      studentName: map['studentName'] as String,
      studentPhone: map['studentPhone'] as String,
      parentPhone: map['parentPhone'] as String,
      academicYear: map['academicYear'] as String,
      groupNames: List<String>.from(map['groupNames'] as List),
      grades: Map<String, dynamic>.from(map['grades'] as Map),
      qrCodeData: map['qrCodeData'] as String,
      createdAt: map['createdAt'] as Timestamp,
      updatedAt: map['updatedAt'] as Timestamp,
    );
  }

  factory Student.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Student.fromMap(data);
  }

  // امتداد (extension) على كلاس Student لتوفير دالة copyWith
  // هذه الدالة تسمح بإنشاء نسخة جديدة من الكائن مع تغيير حقول محددة فقط.
  // تم نقلها إلى هنا لتكون جزءاً من تعريف الكلاس مباشرة أو كامتداد في نفس الملف
  // (لتجنب الأخطاء إذا كانت معرفة في مكان آخر).
  Student copyWith({
    String? username,
    String? studentName,
    String? studentPhone,
    String? parentPhone,
    String? academicYear,
    List<String>? groupNames,
    Map<String, dynamic>? grades,
    String? qrCodeData,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return Student(
      username: username ?? this.username,
      studentName: studentName ?? this.studentName,
      studentPhone: studentPhone ?? this.studentPhone,
      parentPhone: parentPhone ?? this.parentPhone,
      academicYear: academicYear ?? this.academicYear,
      groupNames: groupNames ?? this.groupNames,
      grades: grades ?? this.grades,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}