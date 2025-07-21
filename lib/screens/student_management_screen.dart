import 'package:flutter/material.dart';
import 'package:qabsolaa/models/student.dart';
import 'package:qabsolaa/services/student_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qabsolaa/services/group_service.dart';
import 'package:qabsolaa/models/group.dart';
import 'package:file_picker/file_picker.dart';
import 'package:collection/collection.dart'; // لتسهيل التجميع

// استيرادات PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart'; // لا تزال مطلوبة لطلب الإذن
import 'dart:ui' as ui; // لاستخدام ui.Image
import 'package:flutter/services.dart'
    show ByteData, rootBundle, Uint8List; // لاستخدام rootBundle

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen>
    with TickerProviderStateMixin {
  // TickerProviderStateMixin للأنيميشن
  final StudentService _studentService = StudentService();
  final GroupService _groupService = GroupService();

  // متغيرات للأنيميشن
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  String _selectedFilter = 'الجميع'; // للفلترة حسب المجموعة في الواجهة
  bool _isLoading = false; // لتتبع حالة التحميل

  // نظام الألوان العصري
  static const Color _primaryBlue = Color(0xFF1E88E5);
  static const Color _accentOrange = Color(0xFFFF8A65);
  static const Color _lightGray = Color(0xFFF5F5F5);
  static const Color _darkGray = Color(0xFF424242);
  static const Color _successGreen = Color(0xFF4CAF50);
  static const Color _warningRed = Color(0xFFE57373);

  final List<String> _academicYears = [
    'أولى إعدادي',
    'ثانية إعدادي',
    'ثالثة إعدادي',
    'أولى ثانوي',
    'ثانية ثانوي',
    'ثالثة ثانوي',
  ];

  List<Group> _allAvailableGroups = [];

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
        _allAvailableGroups = groups;
      });
    }, onError: (error) {
      print('Error listening to groups in student_management_screen: $error');
      _showSnackBar('خطأ في تحميل المجموعات: $error', isError: true);
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _warningRed : _successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
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
              _buildModernAppBar(),
              _buildFilterChips(),
              Expanded(child: _buildStudentList()),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'كبسولة: إدارة الطلاب',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildActionButton(
            Icons.file_upload,
            'استيراد Excel',
            _importStudentsFromExcel,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            Icons.qr_code_2,
            'استخراج QR',
            _generateAllQRPdf,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String tooltip, VoidCallback onPressed) {
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

  Widget _buildFilterChips() {
    final filters = ['الجميع', ..._allAvailableGroups.map((g) => g.groupName)];

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = selected ? filter : 'الجميع';
                });
              },
              backgroundColor: Colors.white.withOpacity(0.1),
              selectedColor: _accentOrange,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? _accentOrange
                      : Colors.white.withOpacity(0.3),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStudentList() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        child: StreamBuilder<List<Student>>(
          stream: _studentService.getStudents(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }

            final students = _filterStudents(snapshot.data!);

            students.sort((a, b) {
              String groupNameA =
                  a.groupNames.isNotEmpty ? a.groupNames.first : 'غير مصنف';
              String groupNameB =
                  b.groupNames.isNotEmpty ? b.groupNames.first : 'غير مصنف';

              int groupComparison = groupNameA.compareTo(groupNameB);
              if (groupComparison != 0) return groupComparison;

              return a.studentName.compareTo(b.studentName);
            });

            final Map<String, List<Student>> groupedStudents = groupBy(
                students,
                (student) => student.groupNames.isNotEmpty
                    ? student.groupNames.first
                    : 'غير مصنف');

            final List<String> sortedGroupNames = groupedStudents.keys.toList()
              ..sort();

            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedGroupNames.length,
                  itemBuilder: (context, index) {
                    final groupName = sortedGroupNames[index];
                    final studentsInGroup = groupedStudents[groupName]!;

                    return _buildGroupSection(groupName, studentsInGroup);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Student> _filterStudents(List<Student> students) {
    if (_selectedFilter == 'الجميع') return students;
    return students
        .where((student) => student.groupNames.contains(_selectedFilter))
        .toList();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue),
          ),
          SizedBox(height: 16),
          Text(
            'جاري تحميل الطلاب...',
            style: TextStyle(
              fontSize: 16,
              color: _darkGray,
            ),
          ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد طلاب مسجلون بعد',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على زر + لإضافة طالب جديد',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(String groupName, List<Student> students) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12, top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primaryBlue.withOpacity(0.1),
                _accentOrange.withOpacity(0.1)
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.group, color: _primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                groupName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryBlue,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${students.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...students.map((student) => _buildStudentCard(student)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStudentCard(Student student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showStudentDetails(student),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _primaryBlue,
                      radius: 24,
                      child: Text(
                        student.studentName.isNotEmpty
                            ? student.studentName[0]
                            : 'ط',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.studentName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _darkGray,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            student.academicYear,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildActionButtons(student),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStudentInfo(student),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentInfo(Student student) {
    return Row(
      children: [
        _buildInfoChip(
          Icons.phone,
          student.studentPhone,
          _primaryBlue,
        ),
        const SizedBox(width: 8),
        _buildInfoChip(
          Icons.phone_android,
          student.parentPhone,
          _accentOrange,
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Student student) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton2(
          Icons.qr_code,
          _primaryBlue,
          () => _showQrCodeDialog(context, student), // <--- هنا المشكلة
        ),
        const SizedBox(width: 8),
        _buildActionButton2(
          Icons.edit,
          _successGreen,
          () => _showStudentForm(context, student: student),
        ),
        const SizedBox(width: 8),
        _buildActionButton2(
          Icons.delete,
          _warningRed,
          () => _confirmDeleteStudent(context, student),
        ),
      ],
    );
  }

  Widget _buildActionButton2(
      IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => _showStudentForm(context),
      backgroundColor: _accentOrange,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'إضافة طالب',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showStudentDetails(Student student) {
    _showSnackBar('تم النقر على الطالب: ${student.studentName}',
        isError: false);
  }

  // دالة محسنة لاستيراد الطلاب من Excel
  Future<void> _importStudentsFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isLoading = true);

        _showLoadingDialog('جاري استيراد الطلاب...');

        List<String> importResults =
            await _studentService.importStudentsFromExcel(
          result.files.single.bytes!,
        );

        Navigator.of(context).pop();
        setState(() => _isLoading = false);

        _showImportResultsDialog(importResults);
      } else {
        _showSnackBar('تم إلغاء اختيار الملف.', isError: true);
      }
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      setState(() => _isLoading = false);
      _showSnackBar('حدث خطأ أثناء الاستيراد: $e', isError: true);
      print('Error during Excel import UI: $e');
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue),
            ),
            const SizedBox(height: 16),
            Text(message),
          ],
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

  // دالة لإنشاء PDF يحتوي على جميع رموز QR للطلاب (مع تصميم جديد)
  Future<void> _generateAllQRPdf() async {
    try {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }

      if (!status.isGranted) {
        _showSnackBar(
            'الوصول للتخزين مطلوب لحفظ الملف. الرجاء تفعيله يدوياً من إعدادات التطبيق.',
            isError: true);
        return;
      }

      _showLoadingDialog('جاري إنشاء ملف PDF...');

      final pdf = pw.Document();
      List<Student> students = await _studentService.getStudents().first;

      if (students.isEmpty) {
        Navigator.of(context).pop();
        _showSnackBar('لا يوجد طلاب لإنشاء رموز QR لهم.', isError: true);
        return;
      }

      students.sort((a, b) {
        String groupNameA =
            a.groupNames.isNotEmpty ? a.groupNames.first : 'غير مصنف';
        String groupNameB =
            b.groupNames.isNotEmpty ? b.groupNames.first : 'غير مصنف';

        int groupComparison = groupNameA.compareTo(groupNameB);
        if (groupComparison != 0) return groupComparison;

        return a.studentName.compareTo(b.studentName);
      });

      // تحميل الخط العربي
      final fontData = await rootBundle.load("assets/fonts/arial.ttf");
      final ttf = pw.Font.ttf(fontData.buffer.asByteData());

      // تحميل الشعار
      final ByteData imageData = await rootBundle
          .load('assets/images/app_logo.png'); // تأكد من المسار الصحيح للشعار
      final Uint8List logoBytes = imageData.buffer.asUint8List();

      for (var student in students) {
        if (student.qrCodeData.isEmpty) {
          print('الطالب ${student.studentName} ليس لديه بيانات QR. تم تخطيه.');
          continue;
        }

        final qrPainter = QrPainter(
          data: student.qrCodeData,
          version: QrVersions.auto,
          gapless: false,
        );

        ui.PictureRecorder recorder = ui.PictureRecorder();
        Canvas canvas = Canvas(recorder);
        qrPainter.paint(canvas, const Size(200, 200));
        final ui.Image img = await recorder.endRecording().toImage(200, 200);
        final ByteData? byteData =
            await img.toByteData(format: ui.ImageByteFormat.png);
        final Uint8List pngBytes = byteData!.buffer.asUint8List();

        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Container(
                  // الحاوية البيضاء للخلفية
                  padding: const pw.EdgeInsets.all(30),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white, // خلفية بيضاء
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      // الشعار في الأعلى
                      pw.Image(pw.MemoryImage(logoBytes),
                          width: 80, height: 80), // حجم الشعار
                      pw.SizedBox(height: 20),

                      // الاسم في المنتصف
                      pw.Text(
                        'الاسم: ${student.studentName}',
                        style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            font: ttf), // استخدام الخط العربي
                        textDirection:
                            pw.TextDirection.rtl, // لضمان اتجاه النص العربي
                      ),
                      pw.SizedBox(height: 20),

                      // رمز QR أسفل الاسم
                      pw.Image(pw.MemoryImage(pngBytes),
                          width: 200, height: 200), // حجم QR
                      pw.SizedBox(height: 20),

                      // تفاصيل الطالب الأخرى (يمكن تعديلها أو إزالتها حسب الحاجة)
                      pw.Text(
                        'المجموعة: ${student.groupNames.isNotEmpty ? student.groupNames.first : 'غير مصنف'}',
                        style: pw.TextStyle(fontSize: 18, font: ttf),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.Text(
                        'للعام الدراسي: ${student.academicYear}',
                        style: pw.TextStyle(fontSize: 16, font: ttf),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.Text(
                        'رقم هاتف الطالب: ${student.studentPhone}',
                        style: pw.TextStyle(fontSize: 16, font: ttf),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.Text(
                        'رقم ولي الأمر: ${student.parentPhone}',
                        style: pw.TextStyle(fontSize: 16, font: ttf),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/قبسولة_رموز_QR_الطلاب.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      Navigator.of(context).pop();
      _showSnackBar('تم إنشاء ملف PDF رموز QR وحفظه في: $path', isError: false);
      await OpenFilex.open(path);
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _showSnackBar('حدث خطأ أثناء إنشاء ملف PDF: $e', isError: true);
      print('Error generating QR PDF: $e');
    }
  }

  // دالة لعرض نموذج إضافة/تعديل الطالب
  void _showStudentForm(BuildContext context, {Student? student}) {
    final formKey = GlobalKey<FormState>();
    final studentNameController =
        TextEditingController(text: student?.studentName);
    final studentPhoneController =
        TextEditingController(text: student?.studentPhone);
    final parentPhoneController =
        TextEditingController(text: student?.parentPhone);
    final gradesController =
        TextEditingController(text: jsonEncode(student?.grades ?? {}));
    String? selectedAcademicYear =
        student?.academicYear ?? _academicYears.first;

    String? selectedGroupForStudent = student?.groupNames.isNotEmpty == true
        ? student!.groupNames.first
        : (_allAvailableGroups.isNotEmpty
            ? _allAvailableGroups.first.groupName
            : null);

    if (selectedGroupForStudent == null && _allAvailableGroups.isNotEmpty) {
      selectedGroupForStudent = _allAvailableGroups.first.groupName;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      student == null ? 'إضافة طالب جديد' : 'تعديل طالب',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildFormField(
                      controller: studentNameController,
                      label: 'اسم الطالب',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال اسم الطالب';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      controller: studentPhoneController,
                      label: 'رقم هاتف الطالب',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال رقم هاتف الطالب';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      controller: parentPhoneController,
                      label: 'رقم هاتف ولي الأمر',
                      icon: Icons.phone_android,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال رقم هاتف ولي الأمر';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      value: selectedAcademicYear,
                      label: 'السنة الدراسية',
                      icon: Icons.school,
                      items: _academicYears,
                      onChanged: (value) => selectedAcademicYear = value,
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      value: selectedGroupForStudent,
                      label: 'المجموعة',
                      icon: Icons.group,
                      items:
                          _allAvailableGroups.map((g) => g.groupName).toList(),
                      onChanged: (value) => selectedGroupForStudent = value,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('إلغاء'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              Map<String, dynamic> gradesMap = {};
                              if (gradesController.text.isNotEmpty) {
                                try {
                                  gradesMap = jsonDecode(gradesController.text);
                                } catch (e) {
                                  // Handled by validator
                                }
                              }

                              List<String> studentGroups =
                                  selectedGroupForStudent != null
                                      ? [selectedGroupForStudent!]
                                      : [];

                              if (student == null) {
                                await _studentService.addStudent(
                                  studentName: studentNameController.text,
                                  studentPhone: studentPhoneController.text,
                                  parentPhone: parentPhoneController.text,
                                  academicYear: selectedAcademicYear!,
                                  groupNames: studentGroups,
                                  grades: gradesMap,
                                );
                              } else {
                                final updatedStudent = student.copyWith(
                                  studentName: studentNameController.text,
                                  studentPhone: studentPhoneController.text,
                                  parentPhone: parentPhoneController.text,
                                  academicYear: selectedAcademicYear!,
                                  groupNames: studentGroups,
                                  grades: gradesMap,
                                  updatedAt: Timestamp.now(),
                                );
                                await _studentService
                                    .updateStudent(updatedStudent);
                              }
                              Navigator.of(context).pop();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryBlue),
                          child: Text(student == null ? 'إضافة' : 'تحديث',
                              style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int? maxLines,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primaryBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryBlue.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryBlue, width: 2),
        ),
      ),
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      enabled: enabled,
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primaryBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryBlue.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryBlue, width: 2),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'الرجاء اختيار $label';
        }
        return null;
      },
    );
  }

  // دالة لعرض رمز QR في نافذة منبثقة (داخل التطبيق) - تم تعديلها لتصميم جديد
  void _showQrCodeDialog(BuildContext context, Student student) {
    print(
        '>>> _showQrCodeDialog: Attempting to show QR for student: ${student.studentName}');
    print('>>> _showQrCodeDialog: QR Data received: ${student.qrCodeData}');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('رمز: ${student.studentName}',
              textAlign: TextAlign.center,
              style: TextStyle(color: _darkGray, fontWeight: FontWeight.bold)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero, // إزالة الحشو الافتراضي
          content: Container(
            // الحاوية الرئيسية للتصميم الجديد
            width: MediaQuery.of(context).size.width * 0.8, // عرض أكبر قليلاً
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white, // خلفية بيضاء
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. الشعار في الأعلى
                FutureBuilder<ByteData>(
                  // استخدام FutureBuilder لتحميل الشعار
                  future: rootBundle
                      .load('assets/0.png'), // تأكد من المسار الصحيح للشعار
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData) {
                      return Image.memory(snapshot.data!.buffer.asUint8List(),
                          width: 80, height: 80);
                    }
                    return const SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator()); // مؤشر تحميل
                  },
                ),
                const SizedBox(height: 20),

                // 2. الاسم في المنتصف
                Text(
                  'الاسم: ${student.studentName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue),
                ),
                const SizedBox(height: 20),

                // 3. رمز QR أسفل الاسم
                QrImageView(
                  data: student.qrCodeData,
                  version: QrVersions.auto,
                  size:
                      MediaQuery.of(context).size.width * 0.5, // حجم QR متجاوب
                  gapless: false,
                  errorStateBuilder: (cxt, err) {
                    print('>>> _showQrCodeDialog: QrImageView Error: $err');
                    return Center(
                      child: Text(
                        'حدث خطأ أثناء توليد رمز QR: $err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // زر الإغلاق
                Align(
                  alignment: Alignment.bottomCenter,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child:
                        const Text('إغلاق', style: TextStyle(color: _darkGray)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteStudent(BuildContext context, Student student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف الطالب ${student.studentName}؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _studentService.deleteStudent(student.username);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('تم حذف الطالب ${student.studentName}')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
