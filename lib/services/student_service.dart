import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qabsolaa/models/student.dart'; // تأكد من المسار الصحيح لـ 'qabsolaa'
import 'dart:convert';
import 'package:uuid/uuid.dart';

import 'package:excel/excel.dart'; // حزمة Excel
import 'dart:typed_data'; // لتشغيل Excel

class StudentService {
  final CollectionReference _studentsCollection =
      FirebaseFirestore.instance.collection('students');
  static final Uuid _uuid = Uuid();

  // 1. إضافة طالب جديد
  Future<void> addStudent({
    required String studentName,
    required String studentPhone,
    required String parentPhone,
    required String academicYear,
    required List<String> groupNames,
    Map<String, dynamic> grades = const {},
  }) async {
    final String username = _uuid.v4();

    final Map<String, dynamic> qrDataMap = {
      'username': username,
      'studentName': studentName,
      'studentPhone': studentPhone,
      'parentPhone': parentPhone,
      'academicYear': academicYear,
      'groupNames': groupNames,
      'grades': grades,
    };
    final String qrCodeData = jsonEncode(qrDataMap);

    final Student newStudent = Student(
      username: username,
      studentName: studentName,
      studentPhone: studentPhone, // <--- تم التصحيح هنا
      parentPhone: parentPhone, // <--- تم التصحيح هنا
      academicYear: academicYear,
      groupNames: groupNames,
      grades: grades,
      qrCodeData: qrCodeData,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );

    try {
      await _studentsCollection.doc(username).set(newStudent.toMap());
      print('تم إضافة الطالب $studentName بنجاح. QR Data: $qrCodeData');
    } catch (e) {
      print('Error adding student $studentName: $e');
      rethrow;
    }
  }

  // 1.5. استيراد الطلاب من ملف Excel
  Future<List<String>> importStudentsFromExcel(Uint8List excelBytes) async {
    List<String> importResults = [];

    try {
      var excel = Excel.decodeBytes(excelBytes);

      // نكتفي بمعالجة أول ورقة عمل
      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];

        // <--- تم التصحيح هنا لـ maxRows و maxCols --->
        if (sheet == null || sheet.rows.isEmpty || sheet.row(0).isEmpty) {
          importResults.add("خطأ: ورقة العمل '$table' فارغة أو غير صالحة (لا يوجد رؤوس أعمدة).");
          continue;
        }

        final List<String?> headers = sheet.row(0).map((cell) => cell?.value?.toString()).toList();

        final int nameIndex = headers.indexOf('studentName');
        final int studentPhoneIndex = headers.indexOf('studentPhone');
        final int parentPhoneIndex = headers.indexOf('parentPhone');
        final int academicYearIndex = headers.indexOf('academicYear');
        final int groupNameIndex = headers.indexOf('groupName');
        final int gradesIndex = headers.indexOf('grades');

        if (nameIndex == -1 || studentPhoneIndex == -1 || parentPhoneIndex == -1 ||
            academicYearIndex == -1 || groupNameIndex == -1) {
          importResults.add("خطأ: ورقة العمل '$table' تفتقد إلى الأعمدة الأساسية: studentName, studentPhone, parentPhone, academicYear, groupName.");
          continue;
        }

        // <--- تم التصحيح هنا لـ maxRows --->
        for (int i = 1; i < sheet.rows.length; i++) {
          var row = sheet.row(i);
          if (row.every((cell) => cell?.value == null || cell?.value.toString().trim().isEmpty == true)) {
            continue;
          }

          try {
            final String studentName = row[nameIndex]?.value?.toString().trim() ?? '';
            final String studentPhone = row[studentPhoneIndex]?.value?.toString().trim() ?? '';
            final String parentPhone = row[parentPhoneIndex]?.value?.toString().trim() ?? '';
            final String academicYear = row[academicYearIndex]?.value?.toString().trim() ?? '';
            final String groupNameFromExcel = row[groupNameIndex]?.value?.toString().trim() ?? '';
            
            Map<String, dynamic> grades = {};
            if (gradesIndex != -1 && row[gradesIndex]?.value != null) {
              try {
                grades = jsonDecode(row[gradesIndex]?.value?.toString().trim() ?? '{}');
              } catch (e) {
                print("تحذير: تنسيق الدرجات للطالب $studentName في الصف ${i + 1} غير صحيح. تم تجاهله. الخطأ: $e");
              }
            }

            if (studentName.isEmpty || studentPhone.isEmpty || academicYear.isEmpty || groupNameFromExcel.isEmpty) {
              importResults.add("تحذير: الصف ${i + 1} للطالب '$studentName' يفتقد بيانات أساسية (اسم، هاتف، سنة دراسية، مجموعة). تم تخطيه.");
              continue;
            }

            await addStudent(
              studentName: studentName,
              studentPhone: studentPhone,
              parentPhone: parentPhone,
              academicYear: academicYear,
              groupNames: [groupNameFromExcel],
              grades: grades,
            );
            importResults.add("نجاح: تم إضافة الطالب '$studentName' إلى مجموعة '$groupNameFromExcel'.");

          } catch (e) {
            importResults.add("خطأ في معالجة الصف ${i + 1}: $e");
            print("Error processing row ${i + 1} from Excel: $e");
          }
        }
        break;
      }
    } catch (e) {
      importResults.add("خطأ فادح في قراءة ملف Excel: $e. تأكد من أنه ملف Excel صالح.");
      print("Global Excel read error: $e");
    }

    return importResults;
  }

  // 2. جلب جميع الطلاب
  Stream<List<Student>> getStudents() {
    return _studentsCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Student.fromDocument(doc))
          .toList();
    });
  }

  // 3. جلب طالب بواسطة username
  Future<Student?> getStudentByUsername(String username) async {
    try {
      DocumentSnapshot doc = await _studentsCollection.doc(username).get();
      if (doc.exists) {
        return Student.fromDocument(doc);
      }
      return null;
    } catch (e) {
      print('خطأ في جلب الطالب $username: $e');
      return null;
    }
  }

  // 4. تحديث بيانات طالب
  Future<void> updateStudent(Student student) async {
    final updatedStudent = student.copyWith(updatedAt: Timestamp.now());
    try {
      await _studentsCollection.doc(updatedStudent.username).update(updatedStudent.toMap());
      print('تم تحديث بيانات الطالب ${student.studentName} بنجاح.');
    } catch (e) {
      print('Error updating student ${student.studentName}: $e');
      rethrow;
    }
  }

  // 5. تحديث بيانات الطالب بناءً على وجود QR code data
   Future<void> updateStudentFromQrData(String qrData) async {
    try {
      final Map<String, dynamic> decodedData = jsonDecode(qrData);
      final String username = decodedData['username'] as String;

      DocumentSnapshot doc = await _studentsCollection.doc(username).get();
      if (doc.exists) {
        final Student existingStudent = Student.fromDocument(doc);
        final Student updatedStudent = existingStudent.copyWith(
          studentName: decodedData['studentName'] as String? ?? existingStudent.studentName,
          studentPhone: decodedData['studentPhone'] as String? ?? existingStudent.studentPhone,
          parentPhone: decodedData['parentPhone'] as String? ?? existingStudent.parentPhone,
          academicYear: decodedData['academicYear'] as String? ?? existingStudent.academicYear,
          groupNames: (decodedData['groupNames'] as List?)?.map((e) => e.toString()).toList() ?? existingStudent.groupNames,
          grades: (decodedData['grades'] as Map<String, dynamic>?) ?? existingStudent.grades,
          updatedAt: Timestamp.now(),
        );
        await _studentsCollection.doc(username).update(updatedStudent.toMap());
        print('تم تحديث بيانات الطالب ${existingStudent.studentName} من QR Data.');
      } else {
        print('الطالب ذو اسم المستخدم $username غير موجود. يمكن إضافته كطالب جديد إذا لزم الأمر.');
      }
    } catch (e) {
      print('خطأ في تحديث الطالب من QR Data: $e');
    }
  }

  // 6. حذف طالب
  Future<void> deleteStudent(String username) async {
    try {
      await _studentsCollection.doc(username).delete();
      print('تم حذف الطالب $username بنجاح.');
    } catch (e) {
      print('Error deleting student $username: $e');
      rethrow;
    }
  }
}