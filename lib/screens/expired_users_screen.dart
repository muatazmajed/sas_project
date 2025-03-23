import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../models/debt_model.dart';
import '../services/database_service.dart';
import 'debt_management_screen.dart';
import '../services/global_company.dart';

class ExpiredUsersScreen extends StatefulWidget {
  final String token;

  const ExpiredUsersScreen({Key? key, required this.token}) : super(key: key);

  @override
  _ExpiredUsersScreenState createState() => _ExpiredUsersScreenState();
}

class _ExpiredUsersScreenState extends State<ExpiredUsersScreen> with SingleTickerProviderStateMixin {
  late ApiService _apiService;
  final DatabaseService _databaseService = DatabaseService.instance;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> expiredUsers = [];
  List<Map<String, dynamic>> filteredUsers = [];
  List<Map<String, dynamic>> todayExpiredUsers = [];
  bool isLoading = true;
  String errorMessage = "";
  Timer? _debounce;
  bool _showTodayExpired = false;
  late AnimationController _animationController;
  int _selectedTab = 0;
  
  // ألوان التطبيق المحسنة
  final Color _primaryColor = const Color(0xFF3366FF);
  final Color _secondaryColor = const Color(0xFFF6F8FE);
  final Color _accentColor = const Color(0xFF00C6AE);
  final Color _backgroundColor = Colors.white;
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF1E1E2D);
  final Color _errorColor = const Color(0xFFFF4C5E);
  final Color _warningColor = const Color(0xFFFFAD0D);

  @override
  void initState() {
    super.initState();
    _initApiService();
    _fetchExpiredUsers();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

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

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchExpiredUsers() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      final usersList = await _apiService.getAllUsers(widget.token);
      
      if (usersList.isNotEmpty) {
        debugPrint("نموذج بيانات المستخدم: ${usersList[0].keys.toList()}");
        bool hasPhoneField = usersList[0].containsKey('phone') || 
                            usersList[0].containsKey('phoneNumber') ||
                            usersList[0].containsKey('mobile');
        debugPrint("هل يحتوي على حقل الهاتف: $hasPhoneField");
      }

      DateTime now = DateTime.now();
      DateTime todayStart = DateTime(now.year, now.month, now.day);
      DateTime todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      setState(() {
        expiredUsers = usersList.where((user) {
          if (user['expiration'] == null || user['expiration'].isEmpty) {
            return false;
          }
          try {
            DateTime expiryDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(user['expiration']);
            return now.isAfter(expiryDate);
          } catch (e) {
            debugPrint("خطأ في تنسيق التاريخ: ${user['expiration']}");
            return false;
          }
        }).toList();

        // ترتيب المستخدمين المنتهي اشتراكهم حسب تاريخ انتهاء الاشتراك (الأحدث أولاً)
        expiredUsers.sort((a, b) {
          try {
            DateTime dateA = DateFormat("yyyy-MM-dd HH:mm:ss").parse(a['expiration']);
            DateTime dateB = DateFormat("yyyy-MM-dd HH:mm:ss").parse(b['expiration']);
            return dateB.compareTo(dateA); // ترتيب تنازلي
          } catch (e) {
            return 0;
          }
        });

        todayExpiredUsers = usersList.where((user) {
          if (user['expiration'] == null || user['expiration'].isEmpty) {
            return false;
          }
          try {
            DateTime expiryDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(user['expiration']);
            return expiryDate.isAfter(todayStart) && 
                   expiryDate.isBefore(todayEnd) && 
                   now.isAfter(expiryDate);
          } catch (e) {
            return false;
          }
        }).toList();

        filteredUsers = _showTodayExpired ? todayExpiredUsers : expiredUsers;
        isLoading = false;
        
        // تشغيل الرسوم المتحركة عند اكتمال التحميل
        _animationController.forward();
      });
    } catch (e) {
      debugPrint("حدث خطأ أثناء جلب المستخدمين: $e");
      setState(() {
        isLoading = false;
        errorMessage = "فشل في جلب البيانات: ${e.toString()}";
      });
    }
  }

  void _filterUsers(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        List<Map<String, dynamic>> sourceList = _showTodayExpired ? todayExpiredUsers : expiredUsers;
        filteredUsers = sourceList.where((user) {
          final username = user['username']?.toLowerCase() ?? "";
          final fullName = "${user['firstname'] ?? ''} ${user['lastname'] ?? ''}".trim().toLowerCase();
          return username.contains(query.toLowerCase()) ||
              fullName.contains(query.toLowerCase());
        }).toList();
      });
    });
  }

  void _toggleTodayFilter() {
    setState(() {
      _showTodayExpired = !_showTodayExpired;
      filteredUsers = _showTodayExpired ? todayExpiredUsers : expiredUsers;
      _searchController.clear();
    });
  }

  Future<void> _openWhatsAppWithMessage(String phoneNumber, String userName) async {
    phoneNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    phoneNumber = phoneNumber.replaceAll(RegExp(r'[+()-]'), '');
    
    if (phoneNumber.startsWith('0')) {
      phoneNumber = '964' + phoneNumber.substring(1);
    } else if (!phoneNumber.startsWith('964')) {
      phoneNumber = '964' + phoneNumber;
    }
    
    final String message = 'مرحباً ${userName}،\n'
                  'عزيزي المشترك تم  تفعيل اشتراكك بنجاح ${DateFormat('yyyy/MM/dd').format(DateTime.now())}.\n'
                  'شكراً لثقتك بنا! إذا كانت لديك أية استفسارات، يرجى التواصل معنا.';
    
    final Uri whatsappUriDirect = Uri.parse(
      "whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}"
    );
    
    try {
      bool launched = await launchUrl(
        whatsappUriDirect, 
        mode: LaunchMode.externalNonBrowserApplication,
      );
      
      if (launched) {
        debugPrint("تم فتح واتساب بنجاح في الوضع المباشر");
      } else {
        final Uri whatsappUriFallback = Uri.parse(
          "https://api.whatsapp.com/send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}"
        );
        
        if (await canLaunchUrl(whatsappUriFallback)) {
          await launchUrl(whatsappUriFallback, mode: LaunchMode.externalApplication);
          debugPrint("تم فتح واتساب بالطريقة البديلة");
        } else {
          throw 'لا يمكن فتح واتساب';
        }
      }
    } catch (e) {
      debugPrint("خطأ أثناء فتح واتساب: $e");
      _showSnackBar("تعذر فتح واتساب. الرجاء التأكد من تثبيت التطبيق.", _errorColor);
    }
  }

  Future<void> _showPaymentTypeDialog(int userId, String username) async {
    bool isCredit = false;
    double amount = 0.0;
    DateTime dueDate = DateTime.now().add(Duration(days: 30));
    String notes = '';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.payments_outlined, color: _primaryColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    "طريقة الدفع",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _secondaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              "دفع نقدي",
                              style: TextStyle(
                                fontWeight: isCredit ? FontWeight.normal : FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              "تم استلام المبلغ كاملاً من العميل",
                              style: TextStyle(fontSize: 12),
                            ),
                            leading: Radio<bool>(
                              value: false,
                              groupValue: isCredit,
                              onChanged: (value) {
                                setState(() => isCredit = value!);
                              },
                              activeColor: _primaryColor,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: Text(
                              "دفع آجل",
                              style: TextStyle(
                                fontWeight: isCredit ? FontWeight.bold : FontWeight.normal,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              "سيتم الدفع لاحقاً في تاريخ محدد",
                              style: TextStyle(fontSize: 12),
                            ),
                            leading: Radio<bool>(
                              value: true,
                              groupValue: isCredit,
                              onChanged: (value) {
                                setState(() => isCredit = value!);
                              },
                              activeColor: _primaryColor,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ],
                      ),
                    ),
                    if (isCredit) ...[
                      const SizedBox(height: 20),
                      TextField(
                        decoration: InputDecoration(
                          labelText: "المبلغ المستحق",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: _primaryColor.withOpacity(0.2), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: _primaryColor, width: 1.5),
                          ),
                          prefixIcon: Icon(Icons.attach_money, color: _primaryColor),
                          suffixText: "د.ع",
                          labelStyle: TextStyle(color: _textColor.withOpacity(0.7)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          amount = double.tryParse(value) ?? 0.0;
                        },
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: dueDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 365)),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: _primaryColor,
                                    onPrimary: Colors.white,
                                    surface: _cardColor,
                                    onSurface: _textColor,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null) {
                            setState(() => dueDate = date);
                          }
                        },
                        child: AbsorbPointer(
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: "تاريخ الاستحقاق",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: _primaryColor.withOpacity(0.2), width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: _primaryColor, width: 1.5),
                              ),
                              prefixIcon: Icon(Icons.calendar_today, color: _primaryColor),
                              labelStyle: TextStyle(color: _textColor.withOpacity(0.7)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            ),
                            controller: TextEditingController(
                              text: DateFormat('yyyy/MM/dd').format(dueDate),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          labelText: "ملاحظات",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: _primaryColor.withOpacity(0.2), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: _primaryColor, width: 1.5),
                          ),
                          prefixIcon: Icon(Icons.note, color: _primaryColor),
                          labelStyle: TextStyle(color: _textColor.withOpacity(0.7)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        ),
                        maxLines: 3,
                        onChanged: (value) {
                          notes = value;
                        },
                      ),
                    ],
                  ],
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: _backgroundColor,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: _errorColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text("إلغاء"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (isCredit && amount > 0) {
                      // تسجيل الدين في قاعدة البيانات
                      final debt = DebtModel(
                        userId: userId,
                        username: username,
                        amount: amount,
                        dueDate: dueDate,
                        notes: notes,
                      );
                      
                      await _databaseService.addDebt(debt);
                      
                      _showSnackBar("تم تسجيل الدين بنجاح", _accentColor);
                    }
                    
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text("تأكيد"),
                ),
              ],
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            );
          },
        );
      },
    );
  }

  Future<void> _activateUser(int userId, String username) async {
    if (userId <= 0) {
      debugPrint("معرّف المستخدم غير صالح!");
      return;
    }

    // البحث عن بيانات المستخدم المحدد في القائمة المحلية
    Map<String, dynamic>? userData;
    for (var user in filteredUsers) {
      if (user['id'] == userId) {
        userData = user;
        break;
      }
    }

    // التحقق من وجود بيانات المستخدم
    if (userData == null) {
      debugPrint("لم يتم العثور على بيانات المستخدم!");
      return;
    }

    // استخراج رقم الهاتف من بيانات المستخدم
    String phoneNumber = userData['phone'] ?? '';
    debugPrint("رقم هاتف المستخدم $username: $phoneNumber");

    bool confirmActivation = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: _accentColor, size: 28),
              const SizedBox(width: 16),
              Text(
                "تأكيد التفعيل",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "هل أنت متأكد من أنك تريد تفعيل هذا المستخدم؟",
                style: TextStyle(
                  color: _textColor,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 14, color: _textColor.withOpacity(0.7)),
                  children: [
                    TextSpan(
                      text: "المستخدم: ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: username),
                  ],
                ),
              ),
              if (phoneNumber.isNotEmpty) ...[
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14, color: _textColor.withOpacity(0.7)),
                    children: [
                      TextSpan(
                        text: "رقم الهاتف: ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: phoneNumber),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: _backgroundColor,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: _errorColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text("إلغاء"),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: Icon(Icons.check, size: 18),
              label: Text("تفعيل الاشتراك"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        );
      },
    );

    if (confirmActivation == true) {
      try {
        setState(() {
          isLoading = true;
        });
        
        bool success = await _apiService.toggleUserStatus(widget.token, userId, username);

        if (success) {
          // عرض نافذة اختيار نوع الدفع بعد نجاح التفعيل
          await _showPaymentTypeDialog(userId, username);
          
          // إرسال رسالة واتساب إذا كان رقم الهاتف متوفراً
          if (phoneNumber.isNotEmpty) {
            try {
              await _openWhatsAppWithMessage(phoneNumber, username);
            } catch (e) {
              debugPrint("خطأ في فتح واتساب: $e");
            }
          } else {
            debugPrint("رقم الهاتف غير متوفر للمستخدم: $username");
          }
          
          await _fetchExpiredUsers();
          
          _showSnackBar("تم تفعيل المستخدم بنجاح!", _accentColor);
        } else {
          setState(() {
            isLoading = false;
          });
          
          _showSnackBar("فشل تفعيل المستخدم! حاول مرة أخرى.", _errorColor);
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        
        debugPrint("حدث خطأ أثناء تفعيل المستخدم: $e");
        _showSnackBar("فشل تفعيل المستخدم: ${e.toString()}", _errorColor);
      }
    }
  }
  
  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == _errorColor ? Icons.error : Icons.check_circle, 
              color: Colors.white
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'حسناً',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildSliverAppBar(),
          ];
        },
        body: RefreshIndicator(
          onRefresh: _fetchExpiredUsers,
          color: _primaryColor,
          backgroundColor: Colors.white,
          displacement: 20,
          strokeWidth: 3,
          child: _buildBody(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => 
                DebtManagementScreen(token: widget.token),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                var curve = Curves.easeInOut;
                var curveTween = CurveTween(curve: curve);
                var begin = const Offset(1.0, 0.0);
                var end = Offset.zero;
                var tween = Tween(begin: begin, end: end).chain(curveTween);
                var offsetAnimation = animation.drive(tween);
                return SlideTransition(
                  position: offsetAnimation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        },
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.account_balance_wallet),
        label: const Text("إدارة الديون"),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: _primaryColor,
      elevation: 0,
      automaticallyImplyLeading: false, // إزالة سهم الرجوع التلقائي
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true, // توسيط العنوان
        title: Padding(
          padding: const EdgeInsets.only(right: 16), // إضافة مسافة من اليمين
          child: Text(
            'المستخدمون المنتهي اشتراكهم',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        background: Stack(
          children: [
            // خلفية مميزة
            Positioned(
              top: -20,
              right: -100,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: 30,
              left: -80,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // بيانات إحصائية - عرض العدد الكلي فقط في أعلى اليمين
            Positioned(
              top: 40, // وضعها في الأعلى
              right: 16,
              child: _buildStatCard(
                icon: Icons.people_alt,
                title: "الكل",
                count: expiredUsers.length,
              ),
            ),
          ],
        ),
      ),
      // إزالة جميع الأزرار من شريط العنوان
      actions: [],
    );
  }
  
  Widget _buildStatCard({required IconData icon, required String title, required int count}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
              Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return _buildLoadingIndicator();
    } else if (errorMessage.isNotEmpty) {
      return _buildErrorMessage();
    } else {
      return Column(
        children: [
          _buildSearchFilterBar(),
          Expanded(
            child: _buildUserList(),
          ),
        ],
      );
    }
  }
  
  Widget _buildSearchFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: _backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // بار البحث المحسن
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: _secondaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: _textColor, fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search, 
                  color: _primaryColor,
                  size: 20,
                ),
                hintText: "البحث عن مستخدم...",
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          filteredUsers = _showTodayExpired ? todayExpiredUsers : expiredUsers;
                        });
                      },
                    )
                  : null,
              ),
              onChanged: _filterUsers,
            ),
          ),
          const SizedBox(height: 10),
          
          // خيارات التصفية
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    "عرض:",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _textColor.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: "الكل",
                    icon: Icons.people,
                    isSelected: !_showTodayExpired,
                    onTap: () {
                      if (_showTodayExpired) _toggleTodayFilter();
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: "اليوم",
                    icon: Icons.today,
                    isSelected: _showTodayExpired,
                    onTap: () {
                      if (!_showTodayExpired) _toggleTodayFilter();
                    },
                  ),
                ],
              ),
              AnimatedOpacity(
                opacity: filteredUsers.isNotEmpty ? 1.0 : 0.3,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 14,
                        color: _primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${filteredUsers.length} مستخدم",
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? _primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _primaryColor : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: _primaryColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 1.0).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeInOut,
              ),
            ),
            child: Text(
              "جاري تحميل البيانات...",
              style: TextStyle(
                color: _textColor.withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (filteredUsers.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        // استخدام رسوم متحركة للظهور التدريجي للعناصر
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Interval(
                0.1 + (index * 0.05 > 0.5 ? 0.5 : index * 0.05),
                1.0,
                curve: Curves.easeOut,
              ),
            ),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Interval(
                  0.1 + (index * 0.05 > 0.5 ? 0.5 : index * 0.05),
                  1.0,
                  curve: Curves.easeOut,
                ),
              ),
            ),
            child: _buildUserCard(filteredUsers[index], index),
          ),
        );
      },
    );
  }
  
  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    final username = user['username'] ?? "غير معروف";
    final firstname = user['firstname']?.trim();
    final lastname = user['lastname']?.trim();
    final expirationDateStr = user['expiration'] ?? "غير متوفر";
    
    // تحويل تاريخ الانتهاء إلى صيغة أفضل
    String formattedExpiration = expirationDateStr;
    bool isRecentlyExpired = false;
    String timeAgo = "";
    
    try {
      final expDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(expirationDateStr);
      formattedExpiration = DateFormat("yyyy/MM/dd - HH:mm").format(expDate);
      
      // حساب الفترة منذ انتهاء الاشتراك
      final now = DateTime.now();
      final difference = now.difference(expDate);
      isRecentlyExpired = difference.inDays <= 3;
      
      if (difference.inMinutes < 60) {
        timeAgo = "منذ ${difference.inMinutes} دقيقة";
      } else if (difference.inHours < 24) {
        timeAgo = "منذ ${difference.inHours} ساعة";
      } else {
        timeAgo = "منذ ${difference.inDays} يوم";
      }
    } catch (e) {
      // الاحتفاظ بالصيغة الأصلية إذا كان هناك خطأ
    }

    String displayName = ((firstname == null || firstname.isEmpty) && 
                         (lastname == null || lastname.isEmpty))
        ? username
        : "${firstname ?? ""} ${lastname ?? ""}".trim();
    
    // اختيار لون البطاقة حسب حداثة انتهاء الاشتراك
    Color cardBorderColor = isRecentlyExpired 
        ? _warningColor.withOpacity(0.6)
        : Colors.transparent;
    
    Color timeBadgeColor = isRecentlyExpired
        ? _warningColor
        : Colors.grey.shade500;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cardBorderColor,
          width: isRecentlyExpired ? 1.5 : 0,
        ),
      ),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: InkWell(
          onTap: () => _activateUser(user['id'], username),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserAvatar(username, isRecentlyExpired),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _errorColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  "منتهي",
                                  style: TextStyle(
                                    color: _errorColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "@$username",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: timeBadgeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  timeAgo,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: timeBadgeColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (user.containsKey('phone') && user['phone'] != null && user['phone'].toString().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _accentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        size: 10,
                                        color: _accentColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "متاح",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _accentColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _secondaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_busy,
                        color: isRecentlyExpired ? _warningColor : _textColor.withOpacity(0.6),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "تاريخ انتهاء الاشتراك",
                              style: TextStyle(
                                fontSize: 11,
                                color: _textColor.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formattedExpiration,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isRecentlyExpired ? _warningColor : _textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _activateUser(user['id'], username),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("تفعيل الاشتراك"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 44),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildUserAvatar(String username, bool isRecentlyExpired) {
    // إنشاء متغير لون للأفاتار يعتمد على حالة الاشتراك
    Color avatarColor = isRecentlyExpired 
        ? _warningColor
        : _primaryColor;
    
    // إنشاء تأثير التوهج حول الأفاتار إذا كان الاشتراك منتهيًا حديثًا
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: isRecentlyExpired 
            ? [
                BoxShadow(
                  color: avatarColor.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: CircleAvatar(
        backgroundColor: avatarColor.withOpacity(0.2),
        radius: 24,
        child: CircleAvatar(
          backgroundColor: avatarColor,
          radius: 22,
          child: Text(
            username.isNotEmpty ? username[0].toUpperCase() : "?",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _secondaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showTodayExpired ? Icons.event_available : Icons.people_alt, 
                size: 60, 
                color: _primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _showTodayExpired 
                  ? "لا يوجد مستخدمون منتهي اشتراكهم اليوم" 
                  : "لا يوجد مستخدمون منتهي اشتراكهم",
              style: TextStyle(
                color: _textColor, 
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _showTodayExpired 
                    ? "جميع المستخدمين المشتركين حالياً نشطون أو انتهت اشتراكاتهم في وقت سابق" 
                    : "جميع المستخدمين المشتركين حالياً نشطون",
                style: TextStyle(color: _textColor.withOpacity(0.6), fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            if (_showTodayExpired)
              ElevatedButton.icon(
                onPressed: _toggleTodayFilter,
                icon: const Icon(Icons.people, size: 18),
                label: const Text("عرض كل المستخدمين المنتهي اشتراكهم"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: _errorColor, size: 50),
            ),
            const SizedBox(height: 24),
            Text(
              "حدث خطأ",
              style: TextStyle(
                color: _textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _errorColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _errorColor.withOpacity(0.2)),
              ),
              child: Text(
                errorMessage,
                style: TextStyle(color: _errorColor, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchExpiredUsers,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("إعادة المحاولة"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (index) {
            setState(() {
              _selectedTab = index;
            });
            
            // يمكن هنا إضافة منطق للتنقل بين الشاشات المختلفة
            if (index == 1) {
              // عند النقر على زر الديون
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DebtManagementScreen(token: widget.token),
                ),
              ).then((_) {
                setState(() {
                  _selectedTab = 0;
                });
              });
            }
          },
          backgroundColor: Colors.white,
          selectedItemColor: _primaryColor,
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'المستخدمون',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'الديون',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}