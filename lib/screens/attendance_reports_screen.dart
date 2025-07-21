import 'package:flutter/material.dart';
import 'package:qabsolaa/models/student.dart';
import 'package:qabsolaa/models/attendance_record.dart';
import 'package:qabsolaa/services/student_service.dart';
import 'package:qabsolaa/services/attendance_service.dart';
import 'package:intl/intl.dart'; // لتنسيق التاريخ
import 'package:flutter/services.dart'; // لنسخ النصوص

import 'package:qabsolaa/services/group_service.dart'; // استيراد خدمة المجموعات
import 'package:qabsolaa/models/group.dart'; // استيراد نموذج المجموعة

class AttendanceReportsScreen extends StatefulWidget {
  const AttendanceReportsScreen({super.key});

  @override
  State<AttendanceReportsScreen> createState() => _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState extends State<AttendanceReportsScreen>
    with TickerProviderStateMixin { // TickerProviderStateMixin للأنيميشن
  final StudentService _studentService = StudentService();
  final AttendanceService _attendanceService = AttendanceService();
  final GroupService _groupService = GroupService();

  List<Group> _allGroups = []; // قائمة المجموعات المتاحة ديناميكياً
  String? _selectedGroup; // المجموعة المختارة
  DateTime _selectedDate = DateTime.now(); // التاريخ المختار للتقرير

  String _filterStatus = 'الكل'; // 'الكل', 'حاضر', 'غائب'
  bool _filterIsDelayed = false; // فلتر جديد: مؤجل
  bool _filterNoHomework = false; // فلتر جديد: بدون واجب

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  static const Color _primaryBlue = Color(0xFF1E88E5);
  static const Color _accentOrange = Color(0xFFFF8A65);
  static const Color _lightGray = Color(0xFFF5F5F5);
  static const Color _darkGray = Color(0xFF424242);
  static const Color _successGreen = Color(0xFF4CAF50);
  static const Color _warningRed = Color(0xFFE57373);
  static const Color _infoBlue = Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _listenToGroups();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _listenToGroups() {
    _groupService.getGroups().listen((groups) {
      setState(() {
        _allGroups = groups;
        // <--- التصحيح هنا: نتحقق من _selectedGroup الحالي أولاً --->
        if (_selectedGroup == null || !_allGroups.any((g) => g.groupName == _selectedGroup)) {
          // إذا لم يتم تحديد مجموعة أو المجموعة المختارة لم تعد موجودة
          if (_allGroups.isNotEmpty) {
            _selectedGroup = _allGroups.first.groupName; // اختر أول مجموعة
          } else {
            _selectedGroup = null; // إذا كانت القائمة فارغة، فاجعلها null
          }
        }
      });
    }, onError: (error) {
      print('Error listening to groups in attendance_reports_screen: $error');
      _showSnackBar('خطأ في تحميل المجموعات: $error', color: _warningRed, icon: Icons.error_outline_rounded);
    });
  }

  void _showSnackBar(String message, {required Color color, required IconData icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_primaryBlue, Color(0xFF1976D2)],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(), // AppBar العصري
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  child: Container(
                    color: Colors.white, // خلفية بيضاء للجزء السفلي
                    child: Column(
                      children: [
                        _buildFilterAndDateSelection(), // الفلاتر واختيار التاريخ
                        Expanded(child: _buildAttendanceReportList()), // قائمة التقرير
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'كبسولة: تقارير الحضور',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildActionButton(
            Icons.copy,
            'نسخ بيانات الغياب',
            () => _copyAbsenteesData(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  // دالة لبناء جزء الفلاتر واختيار التاريخ
  Widget _buildFilterAndDateSelection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedGroup,
            decoration: InputDecoration( // استخدام InputDecoration بنفس النمط
              labelText: 'اختر المجموعة',
              labelStyle: const TextStyle(color: _darkGray),
              filled: true,
              fillColor: _lightGray.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primaryBlue, width: 2),
              ),
            ),
            dropdownColor: Colors.white, // لون قائمة الخيارات
            style: const TextStyle(color: _darkGray, fontSize: 16),
            icon: const Icon(Icons.arrow_drop_down, color: _darkGray),
            items: _allGroups.map((group) {
              return DropdownMenuItem(
                value: group.groupName,
                child: Text(group.groupName),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedGroup = value;
              });
            },
            hint: _allGroups.isEmpty && _selectedGroup == null
                ? const Text('لا توجد مجموعات متاحة')
                : null,
          ),
          const SizedBox(height: 16.0),
          ListTile(
            title: Text(
              'التاريخ: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}',
              style: const TextStyle(fontSize: 16, color: _darkGray),
            ),
            trailing: const Icon(Icons.calendar_today, color: _primaryBlue),
            onTap: () => _selectDate(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: _lightGray,
          ),
          const SizedBox(height: 16.0),
          // فلاتر حالة الحضور (حاضر، غائب، الكل)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFilterChip('الكل', 'الكل', _filterStatus == 'الكل', (selected) {
                setState(() {
                  _filterStatus = selected ? 'الكل' : _filterStatus;
                });
              }),
              _buildFilterChip('حاضرون', 'حاضر', _filterStatus == 'حاضر', (selected) {
                setState(() {
                  _filterStatus = selected ? 'حاضر' : _filterStatus;
                });
              }),
              _buildFilterChip('غياب', 'غائب', _filterStatus == 'غائب', (selected) {
                setState(() {
                  _filterStatus = selected ? 'غائب' : _filterStatus;
                });
              }),
            ],
          ),
          const SizedBox(height: 8.0),
          // فلاتر الواجب والتأجيل
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFilterChip('مؤجل', 'مؤجل', _filterIsDelayed, (selected) {
                setState(() {
                  _filterIsDelayed = selected;
                });
              }, icon: Icons.schedule_outlined),
              _buildFilterChip('بدون واجب', 'بدون واجب', _filterNoHomework, (selected) {
                setState(() {
                  _filterNoHomework = selected;
                });
              }, icon: Icons.assignment_late_outlined),
            ],
          ),
        ],
      ),
    );
  }

  // تم تعديل دالة _buildFilterChip لتصبح أكثر مرونة
  Widget _buildFilterChip(String label, String filterValue, bool isSelected,
      ValueChanged<bool> onSelected, {IconData? icon}) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 18, color: isSelected ? Colors.white : _darkGray),
          if (icon != null) const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: _lightGray,
      selectedColor: _primaryBlue.withOpacity(0.8),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : _darkGray,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? _primaryBlue : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildAttendanceReportList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        // <--- تم التصحيح هنا: إضافة شرط تحميل/فارغ دقيق قبل StreamBuilder --->
        child: _selectedGroup == null
            ? (_allGroups.isEmpty) // إذا كانت المجموعات فارغة تمامًا
                ? _buildLoadingState('جاري تحميل المجموعات...', Icons.group_outlined) // عرض تحميل المجموعات
                : _buildEmptyState('الرجاء اختيار مجموعة لعرض التقرير.', Icons.group_outlined)
            : StreamBuilder<List<AttendanceRecord>>(
                stream: _attendanceService.getAttendanceRecords(
                  groupId: _selectedGroup!, // <--- تم إضافة ! هنا (آمن بعد التحقق أعلاه)
                  date: _selectedDate,
                ),
                builder: (context, attendanceSnapshot) {
                  if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState('جاري تحميل سجلات الحضور...', Icons.download_rounded);
                  }
                  if (attendanceSnapshot.hasError) {
                    return _buildErrorState(attendanceSnapshot.error.toString());
                  }

                  final List<AttendanceRecord> attendedRecords = attendanceSnapshot.data ?? [];
                  final Set<String> presentStudentUsernames = attendedRecords.map((e) => e.studentUsername).toSet();
                  final Map<String, AttendanceRecord> detailedAttendedRecords = {
                    for (var record in attendedRecords) record.studentUsername: record
                  };

                  return StreamBuilder<List<Student>>(
                    stream: _studentService.getStudents(),
                    builder: (context, studentsSnapshot) {
                      if (studentsSnapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingState('جاري تحميل بيانات الطلاب...', Icons.person_search_rounded);
                      }
                      if (studentsSnapshot.hasError) {
                        return _buildErrorState(studentsSnapshot.error.toString());
                      }
                      if (!studentsSnapshot.hasData || studentsSnapshot.data!.isEmpty) {
                        return _buildEmptyState('لا يوجد طلاب مسجلون لعرض التقرير.', Icons.school_outlined);
                      }

                      final List<Student> studentsInSelectedGroup = studentsSnapshot.data!
                          .where((student) => student.groupNames.contains(_selectedGroup!)) // <--- تم إضافة ! هنا (آمن بعد التحقق)
                          .toList();

                      if (studentsInSelectedGroup.isEmpty) {
                        return _buildEmptyState('لا يوجد طلاب في مجموعة "${_selectedGroup!}"', Icons.group_off_outlined); // <--- تم إضافة ! هنا (آمن بعد التحقق)
                      }

                      studentsInSelectedGroup.sort((a, b) => a.studentName.compareTo(b.studentName));

                      final List<Student> filteredStudents = studentsInSelectedGroup.where((student) {
                        final bool isPresent = presentStudentUsernames.contains(student.username);
                        final AttendanceRecord? record = detailedAttendedRecords[student.username];

                        // فلترة حسب حالة الحضور (حاضر/غائب/الكل)
                        if (_filterStatus == 'حاضر' && !isPresent) return false;
                        if (_filterStatus == 'غائب' && isPresent) return false;

                        // فلترة حسب مؤجل وبدون واجب (تطبق فقط على الحاضرين الذين لديهم سجل)
                        if (isPresent && record != null) {
                          if (_filterIsDelayed && !record.isDelayed) return false;
                          if (_filterNoHomework && !record.noHomework) return false;
                        } else {
                          // إذا كان الطالب غائباً، فلا ينطبق عليه فلتر التأجيل أو الواجب
                          if (_filterIsDelayed || _filterNoHomework) return false;
                        }
                        
                        return true;
                      }).toList();

                      if (filteredStudents.isEmpty) {
                        String message = 'لا يوجد ';
                        if (_filterStatus == 'حاضر') message += 'حاضرون ';
                        if (_filterStatus == 'غائب') message += 'غياب ';
                        if (_filterIsDelayed) message += 'مؤجلون ';
                        if (_filterNoHomework) message += 'بدون واجب ';
                        message += 'في هذا التاريخ لهذه المجموعة.';

                        return _buildEmptyState(message, Icons.filter_alt_off);
                      }

                      return ListView.builder(
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          final bool isPresent = presentStudentUsernames.contains(student.username);
                          final AttendanceRecord? record = detailedAttendedRecords[student.username];
                          return _buildAttendanceCard(student, isPresent, record);
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  // تم تعديل دالة _buildAttendanceCard لتلقي سجل الحضور
  Widget _buildAttendanceCard(Student student, bool isPresent, AttendanceRecord? record) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: CircleAvatar(
          backgroundColor: isPresent ? _successGreen.withOpacity(0.2) : _warningRed.withOpacity(0.2),
          radius: 20,
          child: Icon(
            isPresent ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: isPresent ? _successGreen : _warningRed,
          ),
        ),
        title: Text(
          student.studentName,
          style: const TextStyle(fontWeight: FontWeight.bold, color: _darkGray),
        ),
        subtitle: Column( // استخدام Column لعرض تفاصيل إضافية
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${student.academicYear} - ${student.groupNames.join(', ')}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (isPresent && record != null) // عرض حالة الحصة والواجب فقط إذا كان حاضراً
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    if (record.isDelayed)
                      _buildStatusChip(
                          'مؤجل', _accentOrange, Icons.schedule_outlined),
                    if (record.isDelayed) const SizedBox(width: 8),
                    if (record.noHomework)
                      _buildStatusChip(
                          'بدون واجب', _warningRed, Icons.assignment_late_outlined),
                  ],
                ),
              ),
          ],
        ),
        trailing: Row( // استخدام Row لوضع حالة الحضور وزر التعديل
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isPresent ? 'حاضر' : 'غائب',
              style: TextStyle(
                color: isPresent ? _successGreen : _warningRed,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isPresent && record != null && record.id != null) // زر التعديل يظهر فقط إذا كان الطالب حاضراً ولديه سجل وله ID
              IconButton(
                icon: const Icon(Icons.edit, color: _primaryBlue),
                onPressed: () => _showEditAttendanceDialog(record), // استدعاء دالة التعديل
                tooltip: 'تعديل حالة الحضور',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // دالة لعرض مربع حوار التعديل
  Future<void> _showEditAttendanceDialog(AttendanceRecord record) async {
    bool currentIsDelayed = record.isDelayed;
    bool currentNoHomework = record.noHomework;

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // المستخدم يجب أن يضغط زر
      builder: (BuildContext context) {
        return StatefulBuilder( // StatefulBuilder لتحديث حالة Checkbox داخل Dialog
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('تعديل حالة الحضور', textAlign: TextAlign.right),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text('الطالب: ${record.studentName}', textAlign: TextAlign.right),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('مؤجل', textAlign: TextAlign.right),
                      value: currentIsDelayed,
                      onChanged: (bool? value) {
                        setState(() {
                          currentIsDelayed = value!;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading, // Checkbox على اليمين
                    ),
                    CheckboxListTile(
                      title: const Text('بدون واجب', textAlign: TextAlign.right),
                      value: currentNoHomework,
                      onChanged: (bool? value) {
                        setState(() {
                          currentNoHomework = value!;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading, // Checkbox على اليمين
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('إلغاء', style: TextStyle(color: _warningRed)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('حفظ التعديلات'),
                  onPressed: () async {
                    if (record.id == null) {
                      _showSnackBar('خطأ: لا يمكن العثور على معرف السجل للتحديث.', color: _warningRed, icon: Icons.error_outline_rounded);
                      Navigator.of(context).pop();
                      return;
                    }
                    try {
                      await _attendanceService.updateAttendanceRecordFields(
                        record.id!,
                        isDelayed: currentIsDelayed,
                        noHomework: currentNoHomework,
                      );
                      _showSnackBar('تم تحديث سجل الحضور بنجاح!', color: _successGreen, icon: Icons.check_circle_outline);
                      Navigator.of(context).pop();
                    } catch (e) {
                      _showSnackBar('خطأ في تحديث السجل: $e', color: _warningRed, icon: Icons.error_outline_rounded);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingState(String message, IconData icon) { // <--- تم تعديلها لاستقبال رسالة وأيقونة
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue),
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: _darkGray,
            ),
          ),
          SizedBox(height: 8),
          Icon(icon, size: 40, color: Colors.grey[400]), // عرض الأيقونة
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: _warningRed,
          ),
          const SizedBox(height: 16),
          Text(
            'حدث خطأ في تحميل البيانات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _darkGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (message.contains('اختيار مجموعة'))
            Text(
              'الرجاء اختيار مجموعة من القائمة أعلاه.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'اختر تاريخ الحصة',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: _primaryBlue,
            colorScheme: const ColorScheme.light(primary: _primaryBlue),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _copyAbsenteesData() async {
    if (_selectedGroup == null) {
      _showSnackBar('الرجاء اختيار مجموعة أولاً لاستخراج الغياب.', color: _warningRed, icon: Icons.error_outline_rounded);
      return;
    }

    final String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    final allStudentsInGroup = await _studentService.getStudents().first.then((students) =>
        students.where((s) => s.groupNames.contains(_selectedGroup!)).toList());

    final attendedRecords = await _attendanceService.getAttendanceRecords(
      groupId: _selectedGroup!,
      date: _selectedDate,
    ).first;

    final Set<String> presentStudentUsernames = attendedRecords.map((e) => e.studentUsername).toSet();

    final List<Student> absentees = allStudentsInGroup
        .where((student) => !presentStudentUsernames.contains(student.username))
        .toList();

    if (absentees.isEmpty) {
      _showSnackBar('لا يوجد غياب في هذا التاريخ لهذه المجموعة.', color: _infoBlue, icon: Icons.info_outline_rounded);
      return;
    }

    String absenteesText = 'قائمة الغياب لمجموعة ${_selectedGroup!} في تاريخ $formattedDate:\n\n';
    for (var student in absentees) {
      absenteesText += 'الاسم: ${student.studentName}\n';
      absenteesText += 'رقم الطالب: ${student.studentPhone}\n';
      absenteesText += 'رقم ولي الأمر: ${student.parentPhone}\n';
      absenteesText += '--------------------\n';
    }

    await Clipboard.setData(ClipboardData(text: absenteesText));
    _showSnackBar('تم نسخ بيانات الغياب إلى الحافظة!', color: _successGreen, icon: Icons.copy_all_rounded);
  }
}