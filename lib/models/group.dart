import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String groupName;
  final String academicYear;
  final String? description;

  Group({
    required this.id,
    required this.groupName,
    required this.academicYear,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupName': groupName,
      'academicYear': academicYear,
      'description': description,
    };
  }

  factory Group.fromMap(String id, Map<String, dynamic> map) {
    return Group(
      id: id,
      groupName: map['groupName'] as String,
      academicYear: map['academicYear'] as String,
      description: map['description'] as String?,
    );
  }

  factory Group.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Group.fromMap(doc.id, data);
  }
}