import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../services/global_company.dart';

class OnlineUsersScreen extends StatefulWidget {
  final String token;

  const OnlineUsersScreen({Key? key, required this.token}) : super(key: key);

  @override
  _OnlineUsersScreenState createState() => _OnlineUsersScreenState();
}

class _OnlineUsersScreenState extends State<OnlineUsersScreen> with SingleTickerProviderStateMixin {
  late ApiService _apiService;
  Future<List<User>>? _onlineUsersFuture;
  List<User> _onlineUsers = [];
  bool _isRefreshing = false;
  bool _isFirstLoad = true;
  bool _isInitializing = true; // إضافة متغير للتحقق من حالة التهيئة
  late AnimationController _refreshIconController;
  
  // ألوان التطبيق الأساسية
  final Color _primaryColor = const Color(0xFF3B82F6); // أزرق
  final Color _secondaryColor = const Color(0xFF10B981); // أخضر
  final Color _accentColor = const Color(0xFFF59E0B); // برتقالي
  final Color _backgroundColor = const Color(0xFFF9FAFB); // رمادي فاتح
  final Color _cardColor = Colors.white;
  final Color _textPrimaryColor = const Color(0xFF1F2937); // رمادي داكن
  final Color _textSecondaryColor = const Color(0xFF6B7280); // رمادي متوسط
  final Color _errorColor = const Color(0xFFEF4444); // أحمر

  @override
  void initState() {
    super.initState();
    _refreshIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // تهيئة ApiService وبدء تحميل البيانات
    _initializeAndFetchData();
  }

  /// تهيئة ApiService وبدء تحميل البيانات
  Future<void> _initializeAndFetchData() async {
    setState(() {
      _isInitializing = true;
    });
    
    // تهيئة ApiService
    await _initApiService();
    
    // تأخير بسيط لضمان اكتمال التهيئة
    await Future.delayed(const Duration(milliseconds: 300));
    
    // بدء تحميل البيانات
    if (mounted) {
      setState(() {
        _onlineUsersFuture = _fetchOnlineUsers();
        _isInitializing = false;
      });
    }
  }

  /// تهيئة ApiService باستخدام الشركة العالمية
  Future<void> _initApiService() async {
    try {
      // استخدام الشركة العالمية إذا كانت موجودة
      if (GlobalCompany.isCompanySet()) {
        debugPrint("🔍 استخدام الشركة العالمية: ${GlobalCompany.getCompanyName()}");
        _apiService = ApiService.fromCompanyConfig(GlobalCompany.getCompany());
      } else {
        // استخدام الشركة الافتراضية
        debugPrint("⚠️ الشركة العالمية غير محددة، استخدام الافتراضية");
        _apiService = ApiService(serverDomain: '');
      }
      
      // طباعة معلومات الاتصال للتشخيص
      _apiService.printServiceInfo();
    } catch (e) {
      debugPrint("❌ خطأ في تهيئة ApiService: $e");
      _apiService = ApiService(serverDomain: '');
    }
  }

  @override
  void dispose() {
    _refreshIconController.dispose();
    super.dispose();
  }

  /// جلب المستخدمين النشطين
  Future<List<User>> _fetchOnlineUsers() async {
    setState(() {
      _isRefreshing = true;
    });
    
    _refreshIconController.repeat();
    
    try {
      // إضافة تأخير بسيط لضمان أن الـ API تم تهيئته بشكل صحيح
      if (_isFirstLoad) {
        await Future.delayed(const Duration(milliseconds: 300));
        _isFirstLoad = false;
      }
      
      List<Map<String, dynamic>> usersData = await _apiService.getOnlineUsers(widget.token);
      List<User> users = usersData.map((data) => User.fromJson(data)).toList();
      
      // ترتيب المستخدمين حسب اسم المستخدم
      users.sort((a, b) => a.username.compareTo(b.username));
      
      if (mounted) {
        setState(() {
          _onlineUsers = users;
          _isRefreshing = false;
        });
      }
      
      _refreshIconController.stop();
      _refreshIconController.reset();
      
      return users;
    } catch (e) {
      debugPrint("❌ خطأ أثناء جلب المستخدمين النشطين: $e");
      
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
      
      _refreshIconController.stop();
      _refreshIconController.reset();
      
      // إعادة محاولة جلب البيانات مرة واحدة في حالة الفشل للمرة الأولى
      if (_isFirstLoad) {
        _isFirstLoad = false;
        await Future.delayed(const Duration(milliseconds: 1000));
        return _fetchOnlineUsers();
      }
      
      throw e; // رمي الخطأ لإظهار واجهة الخطأ
    }
  }

  /// فتح IP في المتصفح
  void _openUserIP(User user) async {
    if (user.ipAddress.isEmpty) {
      _showMessage('عنوان IP غير متوفر لهذا المستخدم', isError: false);
      return;
    }
    
    final url = Uri.parse('http://${user.ipAddress}');
    
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'تعذر فتح الرابط $url';
      }
    } catch (e) {
      if (mounted) {
        _showMessage('تعذر فتح الرابط: ${user.ipAddress}', isError: true);
      }
    }
  }
  
  /// عرض رسالة تنبيه
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? _errorColor : _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'حسناً',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _onlineUsersFuture = _fetchOnlineUsers();
          });
        },
        color: _primaryColor,
        backgroundColor: _cardColor,
        displacement: 20,
        child: _isInitializing 
          ? _buildLoadingIndicator() // عرض مؤشر التحميل أثناء التهيئة
          : FutureBuilder<List<User>>(
              future: _onlineUsersFuture,
              builder: (context, snapshot) {
                // حالات عرض مختلفة بناءً على حالة FutureBuilder
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingIndicator();
                } else if (snapshot.hasError) {
                  return _buildLoadingIndicator(); // عرض مؤشر التحميل بدلاً من رسالة الخطأ
                } else if (!snapshot.hasData || snapshot.data == null) {
                  return _buildLoadingIndicator(); // عرض مؤشر التحميل بدلاً من رسالة الخطأ
                } else if (snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildUserList(snapshot.data!);
              },
            ),
      ),
    );
  }

  /// شريط العنوان
  AppBar _buildAppBar() {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi,
            color: _cardColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            "المستخدمون المتصلون",
            style: TextStyle(
              color: _cardColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, Color(0xFF1E40AF)], // من أزرق فاتح إلى أزرق داكن
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      elevation: 2,
      centerTitle: true,
      toolbarHeight: 56,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: Tween(begin: 0.0, end: 1.0).animate(_refreshIconController),
                child: IconButton(
                  icon: Icon(Icons.refresh, color: _cardColor, size: 22),
                  onPressed: () {
                    if (!_isRefreshing) {
                      setState(() {
                        _onlineUsersFuture = _fetchOnlineUsers();
                      });
                    }
                  },
                  splashRadius: 24,
                  tooltip: 'تحديث',
                ),
              ),
              if (_onlineUsers.isNotEmpty)
                Positioned(
                  top: 10,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _secondaryColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        "${_onlineUsers.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// مؤشر تحميل البيانات
  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: _primaryColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "جاري جلب المستخدمين...",
            style: TextStyle(
              color: _textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// حالة عدم وجود مستخدمين
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.signal_wifi_off_rounded,
              size: 48,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "لا يوجد مستخدمون متصلون حالياً",
            style: TextStyle(
              color: _textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "اسحب للأسفل لتحديث القائمة",
              style: TextStyle(
                color: _textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          _buildButton(
            icon: Icons.refresh_rounded,
            label: "تحديث",
            onPressed: () {
              setState(() {
                _onlineUsersFuture = _fetchOnlineUsers();
              });
            },
            backgroundColor: _primaryColor,
          ),
        ],
      ),
    );
  }

  /// عرض رسالة الخطأ
  Widget _buildErrorMessage(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _errorColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: _errorColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: _textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "حاول مرة أخرى أو تحقق من اتصالك بالإنترنت",
              style: TextStyle(
                color: _textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          _buildButton(
            icon: Icons.refresh_rounded,
            label: "إعادة المحاولة",
            onPressed: () {
              setState(() {
                _onlineUsersFuture = _fetchOnlineUsers();
              });
            },
            backgroundColor: _primaryColor,
          ),
        ],
      ),
    );
  }

  /// زر عام
  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 0,
        minimumSize: const Size(120, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// عرض قائمة المستخدمين
  Widget _buildUserList(List<User> users) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 400),
            child: SlideAnimation(
              verticalOffset: 30.0,
              child: FadeInAnimation(
                child: _buildUserCard(user),
              ),
            ),
          );
        },
      ),
    );
  }

  /// تصميم كرت المستخدم
  Widget _buildUserCard(User user) {
    // حساب النسبة المئوية لأحجام البيانات
    final int totalBytes = user.downloadBytes + user.uploadBytes;
    final double downloadPercentage = totalBytes > 0 ? user.downloadBytes / totalBytes : 0.5;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openUserIP(user),
          splashColor: _primaryColor.withOpacity(0.1),
          highlightColor: _primaryColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // معلومات المستخدم
                Row(
                  children: [
                    _buildUserAvatar(user),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.username,
                            style: TextStyle(
                              color: _textPrimaryColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.language,
                                size: 12,
                                color: _primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  user.ipAddress.isEmpty ? "IP غير متوفر" : user.ipAddress,
                                  style: TextStyle(
                                    color: _textSecondaryColor,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.open_in_browser,
                        size: 14,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // شريط نسبة الاستخدام (التنزيل والرفع)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "استخدام البيانات",
                          style: TextStyle(
                            color: _textPrimaryColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          "الإجمالي: ${_formatBytes(totalBytes)}",
                          style: TextStyle(
                            color: _textSecondaryColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        children: [
                          // شريط التنزيل
                          Expanded(
                            flex: (downloadPercentage * 100).round(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _secondaryColor,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(3),
                                  bottomLeft: const Radius.circular(3),
                                  topRight: downloadPercentage > 0.99 ? const Radius.circular(3) : Radius.zero,
                                  bottomRight: downloadPercentage > 0.99 ? const Radius.circular(3) : Radius.zero,
                                ),
                              ),
                            ),
                          ),
                          // شريط الرفع
                          Expanded(
                            flex: ((1 - downloadPercentage) * 100).round(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _primaryColor,
                                borderRadius: BorderRadius.only(
                                  topRight: const Radius.circular(3),
                                  bottomRight: const Radius.circular(3),
                                  topLeft: downloadPercentage < 0.01 ? const Radius.circular(3) : Radius.zero,
                                  bottomLeft: downloadPercentage < 0.01 ? const Radius.circular(3) : Radius.zero,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
                
                // تفاصيل الاستخدام والوقت
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // تفاصيل التنزيل
                    _buildStatItem(
                      icon: Icons.download,
                      label: "تنزيل",
                      value: user.formattedDownload,
                      color: _secondaryColor,
                    ),
                    // تفاصيل الرفع
                    _buildStatItem(
                      icon: Icons.upload,
                      label: "رفع",
                      value: user.formattedUpload,
                      color: _primaryColor,
                    ),
                    // وقت الاتصال
                    _buildStatItem(
                      icon: Icons.timer,
                      label: "مدة الاتصال",
                      value: user.formattedUptime,
                      color: _accentColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// صورة المستخدم
  Widget _buildUserAvatar(User user) {
    final String initial = user.username.isNotEmpty ? user.username[0].toUpperCase() : "?";
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _primaryColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  /// عنصر إحصائي (تنزيل/رفع/وقت)
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: _textSecondaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  /// تنسيق حجم البيانات
  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return "$bytes B";
    } else if (bytes < (1024 * 1024)) {
      double kb = bytes / 1024;
      return "${kb.toStringAsFixed(1)} KB";
    } else if (bytes < (1024 * 1024 * 1024)) {
      double mb = bytes / (1024 * 1024);
      return "${mb.toStringAsFixed(1)} MB";
    } else {
      double gb = bytes / (1024 * 1024 * 1024);
      return "${gb.toStringAsFixed(1)} GB";
    }
  }
}