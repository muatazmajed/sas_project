import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_internet_speed_test/flutter_internet_speed_test.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:google_fonts/google_fonts.dart';

class SpeedTestPage extends StatefulWidget {
  const SpeedTestPage({Key? key}) : super(key: key);

  @override
  _SpeedTestPageState createState() => _SpeedTestPageState();
}

class _SpeedTestPageState extends State<SpeedTestPage> with SingleTickerProviderStateMixin {
  final FlutterInternetSpeedTest _internetSpeedTest = FlutterInternetSpeedTest()..enableLog();

  bool _testInProgress = false;
  double _downloadSpeed = 0.0;
  double _uploadSpeed = 0.0;
  String _errorMessage = "";
  bool _isServerSelectionComplete = false;
  double _testProgress = 0.0;
  late AnimationController _animationController;

  String? _ip;
  String? _isp;
  
  // ألوان التطبيق الأساسية
  final Color _primaryColor = const Color(0xFF3B82F6); // أزرق
  final Color _secondaryColor = const Color(0xFF10B981); // أخضر
  final Color _accentColor = const Color(0xFFF59E0B); // برتقالي
  final Color _backgroundColor = const Color(0xFF111827); // أسود مائل للرمادي
  final Color _surfaceColor = const Color(0xFF1F2937); // رمادي داكن
  final Color _errorColor = const Color(0xFFEF4444); // أحمر
  final Color _textColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _initializeSpeedTest();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeSpeedTest() async {
    try {
      setState(() {
        _isServerSelectionComplete = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "خطأ أثناء إعداد الاختبار: ${e.toString()}";
      });
    }
  }

  Future<void> _startSpeedTest() async {
    if (_testInProgress || !_isServerSelectionComplete) return;

    setState(() {
      _testInProgress = true;
      _errorMessage = "";
      _downloadSpeed = 0.0;
      _uploadSpeed = 0.0;
      _testProgress = 0.0;
    });
    
    _animationController.repeat();

    try {
      await _internetSpeedTest.startTesting(
        onStarted: () {
          setState(() {
            _testProgress = 0.0;
          });
        },
        onProgress: (double percent, TestResult data) {
          setState(() {
            _testProgress = percent / 100;
            if (data.type == TestType.download) {
              _downloadSpeed = data.transferRate;
            } else {
              _uploadSpeed = data.transferRate;
            }
          });
        },
        onCompleted: (TestResult download, TestResult upload) {
          setState(() {
            _downloadSpeed = download.transferRate;
            _uploadSpeed = upload.transferRate;
            _testInProgress = false;
            _testProgress = 1.0;
          });
          _animationController.stop();
        },
        onDefaultServerSelectionDone: (Client? client) {
          setState(() {
            _ip = client?.ip ?? "غير متاح";
            _isp = client?.isp ?? "غير متاح";
          });
        },
        onError: (String errorMessage, String speedTestError) {
          setState(() {
            _errorMessage = errorMessage;
            _testInProgress = false;
          });
          _animationController.stop();
          
          _showErrorDialog(errorMessage);
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _testInProgress = false;
      });
      _animationController.stop();
      
      _showErrorDialog("فشل في اختبار السرعة: ${e.toString()}");
    }
  }
  
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: _errorColor),
            const SizedBox(width: 10),
            Text(
              "حدث خطأ",
              style: GoogleFonts.cairo(
                color: _textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.cairo(color: _textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "حسناً",
              style: GoogleFonts.cairo(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          "اختبار سرعة الإنترنت",
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _surfaceColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: _textColor),
            onPressed: () {
              _showInfoDialog();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildProgressIndicator(),
                const SizedBox(height: 24),
                
                // Speed gauges
                Row(
                  children: [
                    Expanded(
                      child: _buildSpeedGauge(
                        _downloadSpeed,
                        "التحميل",
                        _primaryColor,
                        Icons.download_rounded,
                      ),
                    ),
                    Expanded(
                      child: _buildSpeedGauge(
                        _uploadSpeed,
                        "الرفع",
                        _accentColor,
                        Icons.upload_rounded,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Connection information
                _buildConnectionInfoCard(),
                
                const SizedBox(height: 32),
                
                // Start test button
                _buildStartTestButton(),
                
                if (_errorMessage.isNotEmpty) 
                  _buildErrorMessage(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildProgressIndicator() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          if (_testInProgress)
            Text(
              "جارِ الاختبار... ${(_testProgress * 100).toStringAsFixed(0)}%",
              style: GoogleFonts.cairo(
                color: _textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _testInProgress ? _testProgress : 0,
            backgroundColor: _surfaceColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              _testProgress <= 0.5 ? _primaryColor : _secondaryColor,
            ),
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedGauge(double speed, String title, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            width: 150,
            child: SfRadialGauge(
              enableLoadingAnimation: true,
              animationDuration: 1000,
              axes: <RadialAxis>[
                RadialAxis(
                  startAngle: 150,
                  endAngle: 30,
                  minimum: 0,
                  maximum: 100,
                  interval: 20,
                  radiusFactor: 0.8,
                  showLabels: false,
                  showAxisLine: false,
                  showTicks: false,
                  ranges: <GaugeRange>[
                    GaugeRange(
                      startValue: 0,
                      endValue: 30,
                      color: _errorColor.withOpacity(0.7),
                      startWidth: 10,
                      endWidth: 10,
                    ),
                    GaugeRange(
                      startValue: 30,
                      endValue: 60,
                      color: _accentColor.withOpacity(0.7),
                      startWidth: 10,
                      endWidth: 10,
                    ),
                    GaugeRange(
                      startValue: 60,
                      endValue: 100,
                      color: _secondaryColor.withOpacity(0.7),
                      startWidth: 10,
                      endWidth: 10,
                    ),
                  ],
                  pointers: <GaugePointer>[
                    NeedlePointer(
                      value: speed,
                      enableAnimation: true,
                      animationDuration: 800,
                      animationType: AnimationType.ease,
                      needleLength: 0.8,
                      needleStartWidth: 1,
                      needleEndWidth: 5,
                      knobStyle: KnobStyle(
                        knobRadius: 8,
                        sizeUnit: GaugeSizeUnit.logicalPixel,
                        color: color,
                      ),
                      tailStyle: const TailStyle(
                        width: 1,
                        length: 0.2,
                      ),
                      needleColor: color,
                    ),
                  ],
                  annotations: <GaugeAnnotation>[
                    GaugeAnnotation(
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${speed.toStringAsFixed(1)}",
                            style: GoogleFonts.roboto(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          Text(
                            "Mbps",
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: _textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      angle: 90,
                      positionFactor: 0.5,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "معلومات الاتصال",
            style: GoogleFonts.cairo(
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            "عنوان IP",
            _ip ?? "غير متاح بعد",
            Icons.language,
            _primaryColor,
          ),
          const Divider(height: 24, color: Colors.grey),
          _buildInfoRow(
            "مزود الخدمة",
            _isp ?? "غير متاح بعد",
            Icons.business,
            _accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: _textColor.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.cairo(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStartTestButton() {
    return ElevatedButton(
      onPressed: _testInProgress ? null : _startSpeedTest,
      style: ElevatedButton.styleFrom(
        backgroundColor: _secondaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _secondaryColor.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
        minimumSize: const Size(double.infinity, 56),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_testInProgress)
            RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(_animationController),
              child: const Icon(Icons.refresh, size: 20),
            )
          else
            const Icon(Icons.speed, size: 20),
          const SizedBox(width: 12),
          Text(
            _testInProgress ? "جارِ الاختبار..." : "بدء اختبار السرعة",
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _errorColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: _errorColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage,
              style: GoogleFonts.cairo(color: _errorColor),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "حول اختبار السرعة",
          style: GoogleFonts.cairo(
            color: _textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoDialogItem(
              "التحميل",
              "سرعة تنزيل البيانات من الإنترنت إلى جهازك.",
              Icons.download_rounded,
              _primaryColor,
            ),
            const SizedBox(height: 16),
            _buildInfoDialogItem(
              "الرفع",
              "سرعة إرسال البيانات من جهازك إلى الإنترنت.",
              Icons.upload_rounded,
              _accentColor,
            ),
            const SizedBox(height: 16),
            Text(
              "ملاحظة: قد تختلف نتائج الاختبار حسب الوقت وحالة الشبكة.",
              style: GoogleFonts.cairo(
                color: _textColor.withOpacity(0.7),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "حسناً",
              style: GoogleFonts.cairo(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoDialogItem(String title, String description, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: GoogleFonts.cairo(
                  color: _textColor.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}