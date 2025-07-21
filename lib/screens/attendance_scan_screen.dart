import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:qabsolaa/services/attendance_service.dart';
import 'package:qabsolaa/services/student_service.dart';
import 'package:qabsolaa/services/group_service.dart';
import 'package:qabsolaa/models/group.dart';

class AttendanceScanScreen extends StatefulWidget {
  const AttendanceScanScreen({super.key});

  @override
  State<AttendanceScanScreen> createState() => _AttendanceScanScreenState();
}

class _AttendanceScanScreenState extends State<AttendanceScanScreen>
    with TickerProviderStateMixin {
  final AttendanceService _attendanceService = AttendanceService();
  final StudentService _studentService = StudentService();
  final GroupService _groupService = GroupService();
  MobileScannerController cameraController = MobileScannerController();

  late AnimationController _pulseController;
  late AnimationController _scanLineController;
  late AnimationController _statusController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _statusAnimation;

  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color accentOrange = Color(0xFFFF8A65);
  static const Color lightBlue = Color(0xFFE3F2FD);
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color errorRed = Color(0xFFF44336);
  static const Color warningAmber = Color(0xFFFFC107);

  String _scanStatus = 'امسح رمز QR للطالب';
  bool _isProcessingScan = false;
  bool _isFlashOn = false;
  List<Group> _allGroups = [];
  String? _selectedGroup;
  Color _statusColor = primaryBlue;
  IconData _statusIcon = Icons.qr_code_scanner_rounded;

  bool _isDelayedSelected = false;
  bool _noHomeworkSelected = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _listenToGroups();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _scanLineController = AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat();
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut));
    _statusController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _statusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _statusController, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
    _statusController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  void _listenToGroups() {
    _groupService.getGroups().listen((groups) {
      setState(() {
        _allGroups = groups;
        if (_selectedGroup == null || !_allGroups.any((g) => g.groupName == _selectedGroup)) {
          _selectedGroup = _allGroups.isNotEmpty ? _allGroups.first.groupName : null;
        }
      });
    }, onError: (error) {
      _updateStatus('خطأ في تحميل المجموعات: $error', color: errorRed, icon: Icons.error_outline_rounded);
    });
  }

  Future<void> _playSound(String assetPath) async {
    try {
      await AudioPlayer().play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing sound from $assetPath: $e');
    }
  }

  void _onQrCodeDetected(BarcodeCapture capture) async {
    if (_isProcessingScan) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? rawQrData = barcodes.first.rawValue;
      if (rawQrData == null) {
        _updateStatus('خطأ: بيانات QR فارغة!', color: errorRed, icon: Icons.error_outline_rounded);
        return;
      }

      setState(() { _isProcessingScan = true; });

      try {
        final Map<String, dynamic> qrDataMap = jsonDecode(rawQrData);
        final String studentUsername = qrDataMap['username'] as String;
        final String studentName = qrDataMap['studentName'] as String? ?? 'طالب غير معروف';
        final List<String> studentGroupNames = (qrDataMap['groupNames'] as List?)?.map((e) => e.toString()).toList() ?? [];

        if (_selectedGroup == null) {
          _updateStatus('الرجاء اختيار مجموعة الحصة أولاً!', color: warningAmber, icon: Icons.warning_rounded);
          await Future.delayed(const Duration(seconds: 2));
          return;
        }

        if (!studentGroupNames.contains(_selectedGroup!)) {
          _updateStatus('الطالب $studentName لا ينتمي للمجموعة المختارة', color: errorRed, icon: Icons.person_off_rounded);
          await Future.delayed(const Duration(seconds: 2));
          return;
        }

        final bool hasAttended = await _attendanceService.hasStudentAttendedToday(studentUsername: studentUsername, attendedGroup: _selectedGroup!);
        if (hasAttended) {
          _updateStatus('✅ تم تسجيل حضور الطالب $studentName مسبقاً لهذا اليوم', color: successGreen, icon: Icons.info_outline_rounded);
          await Future.delayed(const Duration(seconds: 3));
          return;
        }
// ... داخل دالة _onQrCodeDetected ...
await _attendanceService.addOrUpdateAttendanceRecord(
  studentUsername,
  studentName,
  _selectedGroup!,
  _isDelayedSelected, // تمرير حالة زر "مؤجل"
  _noHomeworkSelected, // تمرير حالة زر "بدون واجب"
  null, // <--- تم إضافة المعامل السادس هنا لـ examGrade (بقيمة null)
);
// ...
        _updateStatus('✅ تم تسجيل حضور $studentName بنجاح', color: successGreen, icon: Icons.check_circle_rounded);
        _playSound('sounds/9.mp3');

        setState(() {
          _isDelayedSelected = false;
          _noHomeworkSelected = false;
        });

        await Future.delayed(const Duration(seconds: 2));

      } on FormatException {
        _updateStatus('خطأ: بيانات QR غير صالحة', color: errorRed, icon: Icons.qr_code_scanner_rounded);
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        _updateStatus('خطأ في معالجة البيانات: $e', color: errorRed, icon: Icons.error_outline_rounded);
        await Future.delayed(const Duration(seconds: 2));
      } finally {
        setState(() { _isProcessingScan = false; });
        _updateStatus('امسح الرمز  ', color: primaryBlue, icon: Icons.qr_code_scanner_rounded);
      }
    }
  }

  void _updateStatus(String message, {required Color color, required IconData icon}) {
    setState(() {
      _scanStatus = message;
      _statusColor = color;
      _statusIcon = icon;
    });
    _statusController.reset();
    _statusController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      body: MobileScanner(
        controller: cameraController,
        onDetect: _onQrCodeDetected,
      ),
    );
  }
}
