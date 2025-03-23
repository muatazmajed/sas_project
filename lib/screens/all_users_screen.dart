import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/global_company.dart';

class AllUsersScreen extends StatefulWidget {
  final String token;

  const AllUsersScreen({Key? key, required this.token}) : super(key: key);

  @override
  _AllUsersScreenState createState() => _AllUsersScreenState();
}

class _AllUsersScreenState extends State<AllUsersScreen> {
  late ApiService _apiService;
  final TextEditingController _searchController = TextEditingController();
  Future<List<Map<String, dynamic>>>? _userFuture;
  List<Map<String, dynamic>> _allUsers = [];
  final _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initApiService();
    _userFuture = _fetchAllUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// **🔧 تهيئة ApiService باستخدام الشركة العالمية**
  void _initApiService() {
    try {
      if (GlobalCompany.isCompanySet()) {
        debugPrint("🔍 استخدام الشركة العالمية: ${GlobalCompany.getCompanyName()}");
        _apiService = ApiService.fromCompanyConfig(GlobalCompany.getCompany());
      } else {
        debugPrint("⚠️ الشركة العالمية غير محددة، استخدام الافتراضية");
        _apiService = ApiService(serverDomain: '');
      }
      
      _apiService.printServiceInfo();
    } catch (e) {
      debugPrint("❌ خطأ في تهيئة ApiService: $e");
      _apiService = ApiService(serverDomain: '');
    }
  }

  /// **📡 جلب جميع المستخدمين من API**
  Future<List<Map<String, dynamic>>> _fetchAllUsers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      debugPrint("🔍 بدء جلب جميع المستخدمين...");
      debugPrint("🔑 استخدام التوكن: ${widget.token.length > 20 ? widget.token.substring(0, 20) + '...' : widget.token}");
      
      List<Map<String, dynamic>> users = await _apiService.getAllUsers(widget.token);
      debugPrint("✅ تم جلب ${users.length} مستخدم بنجاح");
      
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
      return users;
    } catch (e) {
      debugPrint("❌ خطأ أثناء جلب البيانات: $e");
      setState(() {
        _isLoading = false;
      });
      return [];
    }
  }

  /// **🔄 إعادة تحميل البيانات**
  Future<void> _refreshData() async {
    debugPrint("🔄 إعادة تحميل بيانات المستخدمين...");
    
    _initApiService();
    
    setState(() {
      _userFuture = _fetchAllUsers();
    });
  }

  /// **🔍 تصفية المستخدمين حسب البحث**
  List<Map<String, dynamic>> _filterUsers(String query) {
    return _allUsers.where((user) {
      final username = user['username']?.toLowerCase() ?? '';
      final fullName =
          "${user['firstname'] ?? ''} ${user['lastname'] ?? ''}".trim().toLowerCase();
      return username.contains(query.toLowerCase()) || fullName.contains(query.toLowerCase());
    }).toList();
  }

  /// **🎨 تحديد لون المستخدم بناءً على تاريخ انتهاء الاشتراك**
  Color _getUserStatus(String? expirationDate) {
    if (expirationDate == null || expirationDate.isEmpty) return Colors.grey;

    try {
      DateTime expiryDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(expirationDate);
      DateTime now = DateTime.now();
      int daysRemaining = expiryDate.difference(now).inDays;
      
      if (now.isAfter(expiryDate)) {
        return Colors.red.shade400; // Expired
      } else if (daysRemaining <= 7) {
        return Colors.orange.shade400; // Expiring soon
      } else {
        return Colors.green.shade400; // Active
      }
    } catch (e) {
      return Colors.grey.shade400;
    }
  }

  String _getStatusText(String? expirationDate) {
    if (expirationDate == null || expirationDate.isEmpty) return "غير محدد";

    try {
      DateTime expiryDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(expirationDate);
      DateTime now = DateTime.now();
      int daysRemaining = expiryDate.difference(now).inDays;
      
      if (now.isAfter(expiryDate)) {
        return "منتهي";
      } else if (daysRemaining <= 7) {
        return "ينتهي قريباً";
      } else {
        return "نشط";
      }
    } catch (e) {
      return "غير محدد";
    }
  }

  /// **🏗️ بناء الواجهة الرسومية**
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "المشتركين", 
        style: TextStyle(
          color: Colors.white, 
          fontWeight: FontWeight.bold,
          fontSize: 20,
        )
      ),
      backgroundColor: Colors.indigo.shade600,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'تحديث',
          onPressed: _refreshData,
        ),
      ],
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        children: [
          _buildHeaderSection(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _userFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingView();
                } else if (snapshot.hasError || snapshot.data == null) {
                  return _buildErrorMessage("❌ خطأ أثناء جلب البيانات!");
                } else if (snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final users = _filterUsers(_searchController.text);
                if (users.isEmpty) {
                  return _buildNoResultsFound();
                }
                return _buildUserList(users);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSearchBar(),
          _buildTotalSubscribers(),
          const SizedBox(height: 8),
          _buildServerInfoBanner(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// **🌐 بانر معلومات الخادم**
  Widget _buildServerInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.cloud, color: Colors.indigo.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                "الشركة: ${_apiService.companyName}",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade700,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.indigo.shade400, size: 20),
            onPressed: _refreshData,
            tooltip: "تحديث البيانات",
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  /// **🔍 شريط البحث**
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, left: 4, right: 4, bottom: 12),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, color: Colors.indigo.shade300),
          hintText: "🔍 البحث عن المشتركين...",
          hintStyle: TextStyle(color: Colors.grey.shade400),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                  });
                },
              )
            : null,
        ),
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  /// **📊 عدد المشتركين الكلي**
  Widget _buildTotalSubscribers() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.people_alt_rounded, color: Colors.indigo.shade400, size: 20),
              const SizedBox(width: 8),
              const Text(
                "عدد المشتركين الكلي:",
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: Colors.black87
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              "${_allUsers.length}",
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold, 
                color: Colors.indigo.shade800
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// **📜 قائمة المستخدمين**
  Widget _buildUserList(List<Map<String, dynamic>> users) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final statusText = _getStatusText(user['expiration']);
        
        return _UserCard(
          user: user,
          statusColor: _getUserStatus(user['expiration']),
          statusText: statusText,
          expiryDate: user['expiration'],
          onSendReminder: () => _sendPaymentReminder(user),
        );
      },
    );
  }

  /// **💬 إرسال تذكير بالدفع عبر واتساب**
  Future<void> _sendPaymentReminder(Map<String, dynamic> user) async {
    final String phoneNumber = user['phone'] ?? '';
    if (phoneNumber.isEmpty) {
      _showSnackBar("رقم الهاتف غير متوفر للمستخدم", Colors.red.shade400);
      return;
    }

    final String fullName = "${user['firstname'] ?? ''} ${user['lastname'] ?? ''}".trim();
    final String username = user['username'] ?? "المستخدم";
    final String displayName = fullName.isNotEmpty ? fullName : username;
    
    // تنظيف رقم الهاتف
    String cleanedPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    cleanedPhone = cleanedPhone.replaceAll(RegExp(r'[+()-]'), '');
    
    // تنسيق رقم الهاتف للعراق
    if (cleanedPhone.startsWith('0')) {
      cleanedPhone = '964' + cleanedPhone.substring(1);
    } else if (!cleanedPhone.startsWith('964')) {
      cleanedPhone = '964' + cleanedPhone;
    }

    // إنشاء رسالة التذكير
    final String message = 'عزيزي المشترك ${displayName}،\n\n'
        'تحية طيبة،\n'
        'نود تذكيركم بضرورة تسديد المبلغ المستحق عليكم من ديون سابقة لتجنب توقف خدمة الإنترنت. يرجى المبادرة بالتسديد في أقرب وقت ممكن وذلك لضمان استمرار تقديم الخدمة لكم بشكل سلس.\n\n'
        'للاستفسار أو التسديد، يرجى التواصل معنا مباشرة على هذا الرقم أو زيارتنا.\n\n'
        'مع خالص الشكر والتقدير';

    // إنشاء رابط واتساب
    final Uri whatsappUri = Uri.parse(
      "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}"
    );
    
    try {
      // محاولة فتح واتساب
      await launchUrl(
        whatsappUri, 
        mode: LaunchMode.externalApplication,
      );
      
      _showSnackBar("تم فتح واتساب لإرسال تنبيه التسديد", Colors.green.shade600);
    } catch (e) {
      debugPrint("❌ خطأ في فتح واتساب: $e");
      
      // محاولة استخدام الرابط المباشر إذا فشلت المحاولة الأولى
      try {
        final Uri directUri = Uri.parse(
          "whatsapp://send?phone=$cleanedPhone&text=${Uri.encodeComponent(message)}"
        );
        await launchUrl(directUri, mode: LaunchMode.externalNonBrowserApplication);
      } catch (e2) {
        _showSnackBar("تعذر فتح واتساب. تأكد من تثبيت التطبيق", Colors.red.shade400);
      }
    }
  }

  /// **🔔 عرض رسالة منبثقة** 
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.red.shade400 ? Icons.error : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.indigo.shade400),
          const SizedBox(height: 16),
          Text(
            "جاري تحميل بيانات المشتركين...",
            style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// **❌ رسالة الخطأ**
  Widget _buildErrorMessage(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
          const SizedBox(height: 16),
          Text(
            message, 
            style: TextStyle(color: Colors.red.shade400, fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text("إعادة المحاولة"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off, color: Colors.grey.shade400, size: 72),
          const SizedBox(height: 16),
          Text(
            "لا يوجد مشتركين بعد",
            style: TextStyle(
              color: Colors.grey.shade700, 
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "سيظهر المشتركون هنا عند إضافتهم",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsFound() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, color: Colors.grey.shade400, size: 64),
          const SizedBox(height: 16),
          Text(
            "لا توجد نتائج مطابقة",
            style: TextStyle(
              color: Colors.grey.shade700, 
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "جرّب كلمات بحث أخرى",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _searchController.clear();
              });
            },
            icon: const Icon(Icons.clear),
            label: const Text("مسح البحث"),
            style: TextButton.styleFrom(
              foregroundColor: Colors.indigo.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// **🎨 تصميم بطاقة المستخدم**
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Color statusColor;
  final String statusText;
  final String? expiryDate;
  final VoidCallback onSendReminder;

  const _UserCard({
    required this.user, 
    required this.statusColor,
    required this.statusText,
    required this.expiryDate,
    required this.onSendReminder,
  });

  String _getExpiryDateFormatted() {
    if (expiryDate == null || expiryDate!.isEmpty) return "—";
    
    try {
      DateTime expDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(expiryDate!);
      return DateFormat("yyyy/MM/dd").format(expDate);
    } catch (e) {
      return "—";
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = "${user['firstname'] ?? ''} ${user['lastname'] ?? ''}".trim();
    final username = user['username'] ?? "غير معروف";
    final initials = _getInitials(fullName, username);
    final phoneAvailable = user.containsKey('phone') && 
                         user['phone'] != null && 
                         user['phone'].toString().isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                _buildAvatar(initials),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isEmpty ? "غير معروف" : fullName,
                        style: const TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.black87
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "@$username",
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                      if (phoneAvailable)
                        Row(
                          children: [
                            Icon(Icons.phone, size: 12, color: Colors.green.shade400),
                            const SizedBox(width: 4),
                            Text(
                              user['phone'],
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
            const Divider(height: 24),
            _buildSubscriptionInfo(),
            if (phoneAvailable) ...[
              const SizedBox(height: 12),
              _buildReminderButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String initials) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            backgroundColor: Colors.indigo.shade100,
            radius: 28,
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.indigo.shade800, 
                fontSize: 18, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: CircleAvatar(
              backgroundColor: statusColor,
              radius: 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.5), width: 1),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor.withOpacity(0.8),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSubscriptionInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildInfoItem(
          Icons.calendar_today_rounded,
          "تاريخ الانتهاء",
          _getExpiryDateFormatted(),
        ),
        _buildInfoItem(
          Icons.supervisor_account_rounded,
          "نوع الحساب",
          user['userType'] ?? "قياسي",
        ),
      ],
    );
  }

  /// **💬 زر إرسال تذكير الدفع**
  Widget _buildReminderButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onSendReminder,
        icon: const Icon(Icons.notification_important_rounded, size: 18),
        label: const Text("إرسال تنبيه للتسديد"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.indigo.shade300),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getInitials(String fullName, String username) {
    if (fullName.isNotEmpty) {
      List<String> nameParts = fullName.split(' ');
      if (nameParts.length > 1) {
        return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
      } else if (nameParts.length == 1 && nameParts[0].isNotEmpty) {
        return nameParts[0][0].toUpperCase();
      }
    }
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }
}