import 'package:flutter/material.dart';
import 'package:qabsolaa/models/student.dart';
import 'package:qabsolaa/models/attendance_record.dart';
import 'package:qabsolaa/services/student_service.dart';
import 'package:qabsolaa/services/attendance_service.dart';
import 'package:qabsolaa/services/group_service.dart';
import 'package:qabsolaa/models/group.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border; // <--- hide Border لتجنب تعارضات

class GradeManagementScreen extends StatefulWidget {
  const GradeManagementScreen({super.key});

  @override
  State<GradeManagementScreen> createState() => _GradeManagementScreenState();
}

class _GradeManagementScreenState extends State<GradeManagementScreen>
    with TickerProviderStateMixin {
  final StudentService _studentService = StudentService();
  final AttendanceService _attendanceService = AttendanceService();
  final GroupService _groupService = GroupService();

  List<Group> _allGroups = [];
  String? _selectedGroup;
  DateTime _selectedDate = DateTime.now();

  Map<String, TextEditingController> _gradeControllers = {};
  Map<String, bool> _delayedStatuses = {};
  Map<String, bool> _homeworkStatuses = {};

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  static const Color _primaryColor = Color(0xFF0F4C75);
  static const Color _primaryDark = Color(0xFF0A3A5C);
  static const Color _accentColor = Color(0xFF3282B8);
  static const Color _successColor = Color(0xFF28A745);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _errorColor = Color(0xFFDC3545);
  static const Color _surfaceColor = Color(0xFFF8F9FA);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF212529);
  static const Color _textSecondary = Color(0xFF6C757D);
  static const Color _borderColor = Color(0xFFDEE2E6);
  static const Color _headerColor = Color(0xFF0F4C75); // تم إضافة هذا اللون
  static const Color _cellBackground = Color(0xFFF8F9FA); // تم إضافة هذا اللون
  static const Color _infoBlue =
      Color(0xFF2196F3); // <--- تأكد من وجود هذا السطر وغير معلق

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
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutQuart,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _gradeControllers.forEach((key, controller) => controller.dispose());
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _listenToGroups() {
    _groupService.getGroups().listen((groups) {
      setState(() {
        _allGroups = groups;
        if (_selectedGroup == null && _allGroups.isNotEmpty) {
          _selectedGroup = _allGroups.first.groupName;
        } else if (_selectedGroup != null &&
            !_allGroups.any((g) => g.groupName == _selectedGroup)) {
          _selectedGroup =
              _allGroups.isNotEmpty ? _allGroups.first.groupName : null;
        }
      });
    }, onError: (error) {
      print('Error listening to groups in grade_management_screen: $error');
      _showModernSnackBar('خطأ في تحميل المجموعات: $error', _errorColor);
    });
  }

  void _showModernSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  color == _successColor
                      ? Icons.check_circle_outline
                      : color == _errorColor
                          ? Icons.error_outline
                          : Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600, // تم تغيير الوزن
                    fontSize: 14, // تم تغيير الحجم
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)), // تم تغيير نصف القطر
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4), // تم تغيير المدة
        elevation: 8,
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Container(
          padding: const EdgeInsets.all(24), // تم تغيير الحشو
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20), // تم تغيير الحشو
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  strokeWidth: 4,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImportResultsDialog(List<String> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نتائج الاستيراد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: results
                .map((result) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(result),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(String message, IconData icon) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40), // تم تغيير الحشو
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Icon(icon, size: 32, color: _textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40), // تم تغيير الحشو
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: _errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'حدث خطأ في تحميل البيانات',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: const TextStyle(
                fontSize: 14,
                color: _textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40), // تم تغيير الحشو
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _textSecondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 64,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (message.contains('اختيار مجموعة'))
              Text(
                'الرجاء اختيار مجموعة من القائمة أعلاه.',
                style: const TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildModernHeader(),
            _buildFiltersSection(),
            Expanded(child: _buildGradesContent()),
            _buildSaveButton(), // زر حفظ التعديلات في الأسفل
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.grade,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة الدرجات',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 26, // تم تغيير الحجم
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6), // تم تغيير الحجم
                    Text(
                      'نظام متقدم لإدارة ومتابعة درجات الطلاب',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400, // تم تغيير الوزن
                      ),
                    ),
                  ],
                ),
              ),
              _buildHeaderActionButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton() {
    return Container(
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16), // تم تغيير نصف القطر
        border: Border.all(color: _accentColor.withOpacity(0.2)),
      ),
      child: Material(
        // إضافة Material و InkWell
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _importGradesFromExcel,
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.upload_file_rounded,
                    color: _accentColor, size: 20), // تم تغيير الأيقونة والحجم
                const SizedBox(width: 8),
                Text(
                  'استيراد Excel',
                  style: TextStyle(
                    color: _accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06), // تم تغيير الشفافية
            offset: const Offset(0, 4), // تم تغيير الإزاحة
            blurRadius: 16, // تم تغيير نصف القطر
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list_rounded,
                  color: _primaryColor, size: 20), // تم تغيير الأيقونة والحجم
              const SizedBox(width: 8),
              const Text(
                'فلاتر البيانات',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20), // تم تغيير الحجم
          Row(
            children: [
              Expanded(flex: 2, child: _buildGroupDropdown()),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: _buildDateSelector()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        color: _cardColor, // تم تغيير اللون
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedGroup,
        decoration: const InputDecoration(
          labelText: 'المجموعة',
          prefixIcon: Icon(Icons.group_outlined,
              color: _primaryColor, size: 20), // تم تغيير الحجم
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        dropdownColor: _cardColor,
        borderRadius: BorderRadius.circular(12),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: _textSecondary),
        items: _allGroups.map((group) {
          return DropdownMenuItem(
            value: group.groupName,
            child: Text(
              group.groupName,
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500), // تم تغيير الحجم والوزن
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedGroup = value;
            _gradeControllers.clear();
            _delayedStatuses.clear();
            _homeworkStatuses.clear();
          });
        },
        hint: _allGroups.isEmpty && _selectedGroup == null
            ? const Text('لا توجد مجموعات متاحة',
                style: TextStyle(color: _textSecondary))
            : null,
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        color: _cardColor, // تم تغيير اللون
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    color: _accentColor, size: 18), // تم تغيير الحجم
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'التاريخ',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: _textSecondary, size: 18), // تم تغيير الحجم
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradesContent() {
    // تم تغيير الاسم من _buildGradesTable
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _selectedGroup == null
                ? _buildEmptyState(
                    'الرجاء اختيار مجموعة لعرض الدرجات.', Icons.group_outlined)
                : StreamBuilder<List<AttendanceRecord>>(
                    stream: _attendanceService.getAttendanceRecords(
                      groupId: _selectedGroup!,
                      date: _selectedDate,
                    ),
                    builder: (context, attendanceSnapshot) {
                      if (attendanceSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return _buildLoadingState('جاري تحميل سجلات الحضور...',
                            Icons.download_rounded);
                      }
                      if (attendanceSnapshot.hasError) {
                        return _buildErrorState(
                            attendanceSnapshot.error.toString());
                      }

                      final List<AttendanceRecord> attendedRecords =
                          attendanceSnapshot.data ?? [];
                      final List<AttendanceRecord> presentRecords =
                          attendedRecords
                              .where((record) =>
                                  record.attendedGroup == _selectedGroup &&
                                  record.attendanceDate ==
                                      DateFormat('yyyy-MM-dd')
                                          .format(_selectedDate))
                              .toList();

                      if (presentRecords.isEmpty) {
                        return _buildEmptyState(
                            'لا يوجد طلاب حاضرون في هذه المجموعة والتاريخ.',
                            Icons.calendar_today_outlined);
                      }

                      for (var record in presentRecords) {
                        if (!_gradeControllers.containsKey(record.id)) {
                          _gradeControllers[record.id!] = TextEditingController(
                              text: record.examGrade?.toString() ?? '');
                          _delayedStatuses[record.id!] = record.isDelayed;
                          _homeworkStatuses[record.id!] = record.noHomework;
                        } else {
                          _gradeControllers[record.id!]!.text =
                              record.examGrade?.toString() ?? '';
                          _delayedStatuses[record.id!] = record.isDelayed;
                          _homeworkStatuses[record.id!] = record.noHomework;
                        }
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: presentRecords.length,
                        itemBuilder: (context, index) {
                          final record = presentRecords[index];
                          return _buildGradeEntryCard(record);
                        },
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradeEntryCard(AttendanceRecord record) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _primaryColor,
                  radius: 20,
                  child: Text(
                    record.studentName.isNotEmpty ? record.studentName[0] : 'ط',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    record.studentName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _textPrimary),
                  ),
                ),
                // حقل درجة الامتحان
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: _gradeControllers[record.id!],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16,
                        color: _primaryColor,
                        fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'الدرجة',
                      labelStyle:
                          TextStyle(color: _textSecondary.withOpacity(0.7)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _borderColor)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _borderColor)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: _primaryColor, width: 2)),
                    ),
                    onChanged: (value) {
                      // القيمة سيتم أخذها من المتحكمات عند الضغط على زر الحفظ
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildStatusToggle(
                    label: 'مؤجل',
                    icon: Icons.schedule_outlined,
                    isSelected: _delayedStatuses[record.id!] ?? false,
                    color: _warningColor,
                    onChanged: (selected) {
                      setState(() {
                        _delayedStatuses[record.id!] = selected;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatusToggle(
                    label: 'بدون واجب',
                    icon: Icons.assignment_outlined,
                    isSelected: _homeworkStatuses[record.id!] ?? false,
                    color: _errorColor,
                    onChanged: (selected) {
                      setState(() {
                        _homeworkStatuses[record.id!] = selected;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusToggle({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : _surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : _borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle : icon,
              size: 16,
              color: isSelected ? color : _textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: _saveAllGradeChanges,
        icon: const Icon(Icons.save, color: Colors.white),
        label: const Text(
          'حفظ التعديلات',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 5,
        ),
      ),
    );
  }

  Future<void> _saveAllGradeChanges() async {
    _showLoadingDialog('جاري حفظ التعديلات...');

    int successfulUpdates = 0;
    int failedUpdates = 0;

    for (var recordId in _gradeControllers.keys) {
      final double? grade = double.tryParse(_gradeControllers[recordId]!.text);
      final bool isDelayed = _delayedStatuses[recordId] ?? false;
      final bool noHomework = _homeworkStatuses[recordId] ?? false;

      try {
        await _attendanceService.updateAttendanceRecordFields(
          recordId,
          isDelayed: isDelayed,
          noHomework: noHomework,
          examGrade: grade,
        );
        successfulUpdates++;
      } catch (e) {
        print('Failed to update record $recordId: $e');
        failedUpdates++;
      }
    }

    Navigator.of(context).pop();

    if (failedUpdates == 0) {
      _showModernSnackBar('تم حفظ جميع التعديلات بنجاح!', _successColor);
    } else {
      _showModernSnackBar(
          'تم حفظ $successfulUpdates تعديل بنجاح، وفشل $failedUpdates تعديل.',
          _errorColor);
    }
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
            primaryColor: _primaryColor,
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _textPrimary,
            ),
            dialogBackgroundColor: _cardColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _gradeControllers.clear();
        _delayedStatuses.clear();
        _homeworkStatuses.clear();
      });
    }
  }

  Future<void> _importGradesFromExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      allowMultiple: false,
      withData: true,
    );

    if (result != null &&
        result.files.single.bytes != null &&
        _selectedGroup != null) {
      _showLoadingDialog('جاري استيراد الدرجات من Excel...');
      List<String> importResults = [];

      try {
        var excel = Excel.decodeBytes(result.files.single.bytes!);
        var sheet = excel.tables[excel.tables.keys.first];

        if (sheet == null || sheet.rows.isEmpty || sheet.row(0).isEmpty) {
          importResults.add("خطأ: ورقة العمل فارغة أو غير صالحة.");
        } else {
          final List<String?> headers =
              sheet.row(0).map((cell) => cell?.value?.toString()).toList();
          final int studentUsernameIndex = headers.indexOf('username');
          final int gradeIndex = headers.indexOf('grade');
          final int delayedIndex = headers.indexOf('delayed');
          final int noHomeworkIndex = headers.indexOf('noHomework');

          if (studentUsernameIndex == -1 || gradeIndex == -1) {
            importResults.add(
                "خطأ: الأعمدة الأساسية (username, grade) مفقودة في ملف Excel.");
          } else {
            for (int i = 1; i < sheet.rows.length; i++) {
              var row = sheet.row(i);
              if (row.every((cell) =>
                  cell?.value == null ||
                  cell?.value.toString().trim().isEmpty == true)) continue;

              try {
                final String username =
                    row[studentUsernameIndex]?.value?.toString().trim() ?? '';
                final double? grade = double.tryParse(
                    row[gradeIndex]?.value?.toString().trim() ?? '');

                final bool? isDelayed = delayedIndex != -1
                    ? (row[delayedIndex]?.value?.toString().toLowerCase() ==
                        'true')
                    : null;
                final bool? noHomework = noHomeworkIndex != -1
                    ? (row[noHomeworkIndex]?.value?.toString().toLowerCase() ==
                        'true')
                    : null;

                if (username.isEmpty || grade == null) {
                  importResults.add(
                      "تحذير: الصف ${i + 1} للطالب '$username' يفتقد اسم المستخدم أو الدرجة. تم تخطيه.");
                  continue;
                }

                final String attendanceDate =
                    DateFormat('yyyy-MM-dd').format(_selectedDate);
                final String recordDocId =
                    '${username}_${attendanceDate}_${_selectedGroup!}';

                await _attendanceService.updateAttendanceRecordFields(
                  recordDocId,
                  isDelayed: isDelayed,
                  noHomework: noHomework,
                  examGrade: grade,
                );
                importResults
                    .add("نجاح: تم تحديث درجة '$username' إلى $grade.");
              } catch (e) {
                importResults.add("خطأ في معالجة الصف ${i + 1}: $e");
              }
            }
          }
        }
      } catch (e) {
        importResults.add(
            "خطأ فادح في قراءة ملف Excel: $e. تأكد من أنه ملف Excel صالح.");
      } finally {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('نتائج استيراد الدرجات'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: importResults.map((res) => Text(res)).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      }
    } else if (_selectedGroup == null) {
      _showModernSnackBar(
          'الرجاء اختيار مجموعة قبل استيراد الدرجات.', _warningColor);
    } else {
      _showModernSnackBar('تم إلغاء اختيار الملف.', _infoBlue);
    }
  }
}
