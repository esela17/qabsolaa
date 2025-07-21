import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qabsolaa/models/attendance_record.dart';
import 'package:intl/intl.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'attendance_records';

  // دالة لإضافة أو تحديث سجل حضور
  Future<void> addOrUpdateAttendanceRecord(
    String studentUsername,
    String studentName,
    String attendedGroup,
    bool isDelayed,
    bool noHomework,
    double? examGrade, // دعم تسجيل درجة الامتحان
  ) async {
    final Timestamp now = Timestamp.now();
    final String attendanceDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final String docId = '${studentUsername}_${attendanceDate}_${attendedGroup}';

    final AttendanceRecord recordToSave = AttendanceRecord(
      id: docId,
      studentUsername: studentUsername,
      studentName: studentName,
      attendedGroup: attendedGroup,
      timestamp: now,
      attendanceDate: attendanceDate,
      isDelayed: isDelayed,
      noHomework: noHomework,
      examGrade: examGrade,
    );

    try {
      await _firestore.collection(_collectionName).doc(docId).set(
            recordToSave.toMap(),
            SetOptions(merge: false),
          );
      print(
          'Attendance record added/updated for $studentName ($studentUsername) in $attendedGroup on $attendanceDate. Delayed: $isDelayed, No Homework: $noHomework, Grade: $examGrade');
    } catch (e) {
      print('Error adding/updating attendance record: $e');
      rethrow;
    }
  }

  // دالة لتحديث الحقول (للتقارير أو تحديث الدرجات)
  Future<void> updateAttendanceRecordFields(
    String recordId, {
    bool? isDelayed,
    bool? noHomework,
    double? examGrade,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (isDelayed != null) updates['isDelayed'] = isDelayed;
      if (noHomework != null) updates['noHomework'] = noHomework;
      if (examGrade != null) updates['examGrade'] = examGrade;

      if (updates.isNotEmpty) {
        await _firestore.collection(_collectionName).doc(recordId).update(updates);
        print('Attendance record $recordId updated successfully. Updates: $updates');
      } else {
        print('No updates provided for record $recordId.');
      }
    } catch (e) {
      print('Error updating attendance record $recordId: $e');
      rethrow;
    }
  }

  // التحقق من حضور الطالب في نفس اليوم والمجموعة
  Future<bool> hasStudentAttendedToday({
    required String studentUsername,
    required String attendedGroup,
  }) async {
    final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String docId = '${studentUsername}_${todayDate}_${attendedGroup}';

    try {
      final DocumentSnapshot doc = await _firestore.collection(_collectionName).doc(docId).get();
      return doc.exists;
    } catch (e) {
      print('Error checking if student attended today: $e');
      return false;
    }
  }

  // الحصول على سجلات الحضور لمجموعة وتاريخ محدد
  Stream<List<AttendanceRecord>> getAttendanceRecords({
    required String groupId,
    required DateTime date,
  }) {
    final String formattedDate = DateFormat('yyyy-MM-dd').format(date);

    return _firestore
        .collection(_collectionName)
        .where('attendedGroup', isEqualTo: groupId)
        .where('attendanceDate', isEqualTo: formattedDate)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AttendanceRecord.fromMap(doc.data(), id: doc.id))
          .toList();
    });
  }

  // الحصول على كل سجلات الحضور (استخدام إداري)
  Stream<List<AttendanceRecord>> getAllAttendanceRecords() {
    return _firestore.collection(_collectionName).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AttendanceRecord.fromMap(doc.data(), id: doc.id))
          .toList();
    });
  }
}
