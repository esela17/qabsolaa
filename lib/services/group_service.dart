import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qabsolaa/models/group.dart'; // <--- تأكد أن هذا السطر موجود وصحيح

class GroupService {
  final CollectionReference _groupsCollection =
      FirebaseFirestore.instance.collection('groups');

  // 1. إضافة مجموعة جديدة
  Future<void> addGroup({
    required String groupName,
    required String academicYear,
    String? description,
  }) async {
    // إنشاء كائن Group هنا باستخدام الـ constructor الصحيح
    final Group newGroup = Group( // <--- تم التأكد من صحة هذا السطر
      id: groupName, // استخدام اسم المجموعة كـ ID للوثيقة لسهولة الوصول
      groupName: groupName,
      academicYear: academicYear,
      description: description,
    );
    try {
      await _groupsCollection.doc(groupName).set(newGroup.toMap());
      print('تم إضافة المجموعة $groupName بنجاح.');
    } catch (e) {
      print('Error adding group $groupName: $e');
      rethrow;
    }
  }

  // 2. جلب جميع المجموعات
  Stream<List<Group>> getGroups() {
    return _groupsCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Group.fromDocument(doc))
          .toList();
    });
  }

  // 3. جلب مجموعة بواسطة اسمها
  Future<Group?> getGroupByName(String groupName) async {
    try {
      DocumentSnapshot doc = await _groupsCollection.doc(groupName).get();
      if (doc.exists) {
        return Group.fromDocument(doc);
      }
      return null;
    } catch (e) {
      print('خطأ في جلب المجموعة $groupName: $e');
      return null;
    }
  }

  // 4. تحديث بيانات مجموعة
  Future<void> updateGroup(Group group) async {
    try {
      // هنا، أنت تستلم كائن group بالفعل. نقوم بإنشاء نسخة جديدة (لضمان الثبات)
      // ولكن استخدام group.toMap() مباشرة قد يكون كافياً أيضاً
      final Group updatedGroup = Group( // <--- تم التأكد من صحة هذا السطر
        id: group.id,
        groupName: group.groupName,
        academicYear: group.academicYear,
        description: group.description,
      );
      await _groupsCollection.doc(updatedGroup.id).update(updatedGroup.toMap());
      print('تم تحديث بيانات المجموعة ${group.groupName} بنجاح.');
    } catch (e) {
      print('Error updating group ${group.groupName}: $e');
      rethrow;
    }
  }

  // 5. حذف مجموعة
  Future<void> deleteGroup(String groupId) async {
    try {
      await _groupsCollection.doc(groupId).delete();
      print('تم حذف المجموعة $groupId بنجاح.');
    } catch (e) {
      print('Error deleting group $groupId: $e');
      rethrow;
    }
  }
}