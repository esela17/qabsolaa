import 'package:flutter/material.dart';
import 'package:qabsolaa/models/student.dart';
import 'package:qabsolaa/models/attendance_record.dart';
import 'package:qabsolaa/services/attendance_service.dart';
import 'package:intl/intl.dart';

class StudentDetailsScreen extends StatefulWidget {
  final Student student; // استلام كائن الطالب

  const StudentDetailsScreen({super.key, required this.student});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen>
    with TickerProviderStateMixin {
  final AttendanceService _attendanceService = AttendanceService();

  // نظام الألوان (نفس الألوان المستخدمة في الشاشات الأخرى)
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

  late AnimationController _headerSlideController;
  late Animation<Offset> _headerSlideAnimation;

  @override
  void initState() {
    super.initState();
    _headerSlideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerSlideController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _headerSlideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStudentInfoCard(),
                  const SizedBox(height: 20),
                  _buildAttendanceSummary(),
                  const SizedBox(height: 20),
                  _buildAttendanceRecordsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SlideTransition(
      position: _headerSlideAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'تفاصيل ${widget.student.studentName}',
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: _primaryColor,
              radius: 40,
              child: Text(
                widget.student.studentName.isNotEmpty ? widget.student.studentName[0] : 'ط',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.student.studentName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            Text(
              widget.student.academicYear,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoRow(Icons.phone_outlined, 'هاتف الطالب', widget.student.studentPhone, _primaryColor),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.phone_android_outlined, 'هاتف ولي الأمر', widget.student.parentPhone, _accentColor),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.group_outlined, 'المجموعات', widget.student.groupNames.join(', '), _successColor),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: _textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceSummary() {
    return StreamBuilder<List<AttendanceRecord>>(
      stream: _attendanceService.getAllAttendanceRecords().map((records) => records.where((r) => r.studentUsername == widget.student.username).toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('خطأ في تحميل ملخص الحضور: ${snapshot.error}', style: TextStyle(color: _errorColor));
        }
        final records = snapshot.data ?? [];
        
        final int totalAttendance = records.length;
        final int delayedCount = records.where((r) => r.isDelayed).length;
        final int noHomeworkCount = records.where((r) => r.noHomework).length;
        final double averageGrade = records.isNotEmpty
            ? records.where((r) => r.examGrade != null).map((r) => r.examGrade!).average
            : 0.0;
        
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ملخص الحضور والدرجات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const Divider(height: 25),
                _buildSummaryRow('إجمالي الحصص المسجلة:', '$totalAttendance حصة', Icons.event, _primaryColor),
                _buildSummaryRow('متوسط الدرجة:', averageGrade.toStringAsFixed(1), Icons.star_half, _successColor),
                _buildSummaryRow('حصص مؤجلة:', '$delayedCount حصة', Icons.schedule, _warningColor),
                _buildSummaryRow('مرات بدون واجب:', '$noHomeworkCount مرة', Icons.assignment_late, _errorColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 15, color: _textPrimary),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceRecordsList() {
    return StreamBuilder<List<AttendanceRecord>>(
      stream: _attendanceService.getAllAttendanceRecords().map((records) => records.where((r) => r.studentUsername == widget.student.username).toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('خطأ في تحميل سجلات الحضور: ${snapshot.error}', style: TextStyle(color: _errorColor));
        }
        final records = snapshot.data ?? [];

        if (records.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'لا توجد سجلات حضور لهذا الطالب.',
                style: TextStyle(fontSize: 16, color: _textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        records.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // فرز حسب الأحدث

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Text(
                'سجل الحضور المفصل',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: records.map((record) => _buildAttendanceRecordTile(record)).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAttendanceRecordTile(AttendanceRecord record) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderColor.withOpacity(0.5))),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: record.isDelayed ? _warningColor.withOpacity(0.1) : _successColor.withOpacity(0.1),
          child: Icon(
            record.isDelayed ? Icons.schedule : Icons.check_circle_outline,
            color: record.isDelayed ? _warningColor : _successColor,
          ),
        ),
        title: Text(
          '${record.attendedGroup} - ${DateFormat('dd MMMM yyyy', 'ar').format(record.timestamp.toDate())}',
          style: const TextStyle(fontWeight: FontWeight.w600, color: _textPrimary),
        ),
        subtitle: Text(
          record.noHomework ? 'بدون واجب' : 'أتم الواجب',
          style: TextStyle(
            color: record.noHomework ? _errorColor : _successColor,
            fontSize: 13,
          ),
        ),
        trailing: Text(
          record.examGrade != null ? 'الدرجة: ${record.examGrade!.toStringAsFixed(1)}' : 'لا توجد درجة',
          style: TextStyle(
            color: record.examGrade != null ? _primaryColor : _textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// امتداد لميزة average()
extension IterableDoubleAverage on Iterable<double> {
  double get average {
    if (isEmpty) return 0.0;
    return reduce((a, b) => a + b) / length;
  }
}