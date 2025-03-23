import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loginsignup_new/screens/speed_test_service.dart';
import 'package:loginsignup_new/screens/subscription_expired_screen.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../services/ping_service.dart';
import '../services/global_company.dart';
import '../services/simple_subscription_service.dart';
import '../services/token_refresh_service.dart'; // استيراد خدمة تجديد التوكن
import 'online_users_screen.dart';
import 'all_users_screen.dart';
import 'expired_users_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:intl/date_symbol_data_local.dart';
import 'package:loginsignup_new/screens/signin.dart';
import 'package:loginsignup_new/widgets/custom_drawer.dart';
import 'package:http/http.dart' as http;

// Constants for notification channels
const String WELCOME_CHANNEL_ID = 'welcome_channel';
const String WELCOME_CHANNEL_NAME = 'ترحيب بالمستخدم';
const String WELCOME_CHANNEL_DESC = 'إشعارات ترحيبية للمستخدم عند أول تسجيل دخول';

const String SUBSCRIPTION_CHANNEL_ID = 'subscription_expiry_channel';
const String SUBSCRIPTION_CHANNEL_NAME = 'تنبيه انتهاء الاشتراك';
const String SUBSCRIPTION_CHANNEL_DESC = 'إشعارات خاصة بانتهاء اشتراكات المستخدمين';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class Dashboard extends StatefulWidget {
  final String token;

  const Dashboard({Key? key, required this.token}) : super(key: key);

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  // ===== الخدمات والحالة =====
  late ApiService _apiService;
  final PingService _pingService = PingService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // ===== بيانات المستخدم =====
  String currentUserName = "جارٍ التحميل...";
  String currentUserRole = "مدير النظام";
  String currentUserEmail = "";
  String? userAvatarUrl;

  // ===== بيانات الإحصائيات =====
  int onlineUsers = 0;
  int totalUsers = 0;
  int offlineUsers = 0;
  int facebookPing = -1;
  int googlePing = -1;
  int tiktokPing = -1;
  bool isLoading = true;
  String errorMessage = "";
  int _selectedIndex = 0;
  DateTime lastUpdateTime = DateTime.now();

  // ===== المؤقتات =====
  late Timer _timer;
  bool _isRefreshingData = false;

  // ===== ألوان التطبيق =====
  final Color _primaryColor = const Color(0xFF3B82F6);
  final Color _secondaryColor = const Color(0xFF10B981);
  final Color _accentColor = const Color(0xFFF59E0B);
  final Color _backgroundColor = const Color(0xFF0F172A);
  final Color _surfaceColor = const Color(0xFF1E293B);
  final Color _cardColor = const Color(0xFF334155);
  final Color _textColor = Colors.white;

  @override
  void initState() {
    super.initState();
    // تهيئة التاريخ العربي
    initializeDateFormatting('ar', null);
    
    // إضافة مراقب دورة حياة التطبيق
    WidgetsBinding.instance.addObserver(this);

    // تهيئة ApiService بناءً على الشركة العالمية
    _initApiService();
    
    // تهيئة الإشعارات والأذونات
    _initNotifications();
    _requestPermissions();
    
    // حفظ التوكن وتهيئة الخدمات
    _saveToken();
    
    // بدء خدمة تجديد التوكن التلقائي
    TokenRefreshService().startAutoRefresh();

    // التحقق من حالة الاشتراك قبل تحميل البيانات
    _checkSubscriptionStatus();

    // تأخير لإعطاء وقت لتهيئة ApiService
    Future.delayed(const Duration(milliseconds: 500), () {
      _fetchData();
      _startTimer();
    });

    // تحميل ملف تعريف المستخدم والتحقق من تسجيل الدخول الأول
    _loadUserProfile();
    _checkFirstLoginAndShowWelcomeNotification();

    // التحقق من المستخدمين المنتهية اشتراكاتهم مرة واحدة بعد التشغيل
    Future.delayed(const Duration(seconds: 3), () {
      _checkExpiredUsersOnce();
    });
  }

  @override
  void dispose() {
    // إلغاء تسجيل مراقب دورة الحياة
    WidgetsBinding.instance.removeObserver(this);
    
    // إلغاء المؤقت
    _timer.cancel();
    
    // لاحظ: لا نقوم بإيقاف خدمة تجديد التوكن هنا لأنها يجب أن تستمر في العمل في الخلفية
    // سيتم إيقافها فقط عند تسجيل الخروج أو انتهاء الاشتراك
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      // التطبيق دخل إلى الخلفية، إلغاء المؤقت لتوفير موارد النظام
      _timer.cancel();
      
      // لا نوقف خدمة تجديد التوكن هنا لأنها ستعمل في الخلفية
    } else if (state == AppLifecycleState.resumed) {
      // التطبيق عاد إلى المقدمة، إعادة بدء المؤقت
      _startTimer();
      
      // التحقق من حالة الاشتراك والبيانات
      _checkSubscriptionStatus();
      _fetchData();
      
      // تحديث آخر وقت تحديث
      setState(() {
        lastUpdateTime = DateTime.now();
      });
      
      // تنفيذ تجديد فوري للتوكن عند العودة للتطبيق
      TokenRefreshService().forceRefreshNow();
    }
  }

  // ===== تهيئة ApiService =====
  void _initApiService() {
    try {
      if (GlobalCompany.isCompanySet()) {
        debugPrint("استخدام الشركة العالمية: ${GlobalCompany.getCompanyName()}");
        _apiService = ApiService.fromCompanyConfig(GlobalCompany.getCompany());
      } else {
        debugPrint("الشركة العالمية غير محددة، استخدام الافتراضية");
        _apiService = ApiService(serverDomain: '');
      }
      _apiService.printServiceInfo();
    } catch (e) {
      debugPrint("خطأ في تهيئة ApiService: $e");
      _apiService = ApiService(serverDomain: '');
    }
  }

  // ===== التحقق من حالة الاشتراك =====
  Future<void> _checkSubscriptionStatus() async {
    try {
      debugPrint("التحقق من حالة الاشتراك...");
      final prefs = await SharedPreferences.getInstance();
      String? username = prefs.getString('username');
      String? companyType = prefs.getString('company_type');

      if (username == null || username.isEmpty || companyType == null || companyType.isEmpty) {
        debugPrint("معلومات غير كافية للتحقق من حالة الاشتراك");
        return;
      }

      bool isSubscriptionActive = await SimpleSubscriptionService.checkSubscriptionStatus(username, companyType);

      if (!isSubscriptionActive) {
        debugPrint("انتهى الاشتراك - جاري التوجيه إلى شاشة انتهاء الاشتراك");
        _navigateToExpiredScreen();
        return;
      }

      debugPrint("الاشتراك نشط");
    } catch (e) {
      debugPrint("خطأ في التحقق من حالة الاشتراك: $e");
    }
  }

  // ===== التوجيه إلى شاشة انتهاء الاشتراك =====
  void _navigateToExpiredScreen() {
    // إيقاف خدمة تجديد التوكن عند انتهاء الاشتراك
    TokenRefreshService().stopAutoRefresh();
    
    Get.offAll(() => const SubscriptionExpiredScreen());
  }

  // ===== بدء مؤقت تحديث البيانات =====
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchData();
      
      // التحقق من الاشتراك كل 10 دورات (5 دقائق)
      if (timer.tick % 10 == 0) {
        _periodicSubscriptionCheck();
      }
    });
  }

  // ===== التحقق الدوري من حالة الاشتراك =====
  Future<void> _periodicSubscriptionCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? username = prefs.getString('username');
      String? companyType = prefs.getString('company_type');

      if (username == null || username.isEmpty || companyType == null || companyType.isEmpty) {
        debugPrint("معلومات غير كافية للتحقق الدوري من الاشتراك");
        return;
      }

      bool isSubscriptionActive = await SimpleSubscriptionService.checkSubscriptionStatus(username, companyType);

      if (!isSubscriptionActive) {
        debugPrint("تم اكتشاف انتهاء الاشتراك أثناء الاستخدام");
        _navigateToExpiredScreen();
      }
    } catch (e) {
      debugPrint("خطأ أثناء التحقق الدوري من الاشتراك: $e");
    }
  }

  // ===== حفظ التوكن وإعداد المهام الخلفية =====
  Future<void> _saveToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_token', widget.token);
      await prefs.setString('authToken', widget.token);
      debugPrint("تم حفظ التوكن: ${widget.token.substring(0, min(10, widget.token.length))}...");
      await _registerBackgroundTasks();
    } catch (e) {
      debugPrint("خطأ في حفظ التوكن: $e");
    }
  }

  // ===== تسجيل المهام الخلفية =====
  Future<void> _registerBackgroundTasks() async {
    try {
      await Workmanager().cancelAll();
      await Workmanager().registerPeriodicTask(
        "checkExpiredUsersTask",
        "checkExpiredUsers",
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 1),
      );

      await Workmanager().registerPeriodicTask(
        "checkCurrentUserSubscriptionTask",
        "checkCurrentUserSubscription",
        frequency: const Duration(hours: 1),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      debugPrint("تم تسجيل المهام الخلفية بنجاح");
    } catch (e) {
      debugPrint("خطأ في تسجيل المهام الخلفية: $e");
    }
  }

  // ===== تحميل ملف تعريف المستخدم =====
  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? username = prefs.getString('username');

      if (username != null && username.isNotEmpty) {
        setState(() {
          currentUserName = username;
        });

        try {
          // يمكن جلب المزيد من بيانات المستخدم من الخادم (اختياري)
        } catch (apiError) {
          debugPrint("فشل في جلب بيانات المستخدم الإضافية: $apiError");
        }
      } else {
        debugPrint("اسم المستخدم غير موجود في التخزين المحلي");
      }
    } catch (e) {
      debugPrint("خطأ في تحميل ملف تعريف المستخدم: $e");
    }
  }

  // ===== تسجيل الخروج =====
  Future<void> _logout() async {
    try {
      // إيقاف خدمة تجديد التوكن عند تسجيل الخروج
      await TokenRefreshService().stopAutoRefresh();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('api_token');
      await prefs.remove('authToken');
      await prefs.remove('username');
      await prefs.remove('user_password'); // حذف كلمة المرور المخزنة
      await prefs.remove('user_data');
      await Workmanager().cancelAll();
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => Signin()),
        (route) => false,
      );
    } catch (e) {
      debugPrint("خطأ في تسجيل الخروج: $e");
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => Signin()),
        (route) => false,
      );
    }
  }

  // ===== جلب البيانات =====
  Future<void> _fetchData() async {
    // تجنب التداخل في عمليات تحديث البيانات
    if (_isRefreshingData) return;
    _isRefreshingData = true;
    
    debugPrint("بدء تحديث البيانات...");
    try {
      await _fetchUserStats();
      await _fetchPings();
      
      setState(() {
        lastUpdateTime = DateTime.now();
        _isRefreshingData = false;
      });
    } catch (e) {
      debugPrint("خطأ عام في تحديث البيانات: $e");
      _isRefreshingData = false;
    }
  }

  // ===== جلب إحصائيات المستخدمين =====
  Future<void> _fetchUserStats() async {
    try {
      debugPrint("جلب إحصائيات المستخدمين...");
      debugPrint("استخدام التوكن: ${widget.token.length > 20 ? widget.token.substring(0, 20) + '...' : widget.token}");

      try {
        final testUrl = Uri.parse(_apiService.baseUrl);
        debugPrint("اختبار اتصال الخادم: $testUrl");
        final testResponse = await http.get(testUrl).timeout(const Duration(seconds: 10));
        debugPrint("استجابة اختبار اتصال الخادم: ${testResponse.statusCode}");

        if (testResponse.statusCode != 200) {
          debugPrint("استجاب الخادم برمز حالة غير متوقع: ${testResponse.statusCode}");
          debugPrint("محتوى الاستجابة: ${testResponse.body.length > 100 ? testResponse.body.substring(0, 100) + '...' : testResponse.body}");
        }
      } catch (e) {
        debugPrint("فشل اختبار اتصال الخادم المباشر: $e");
      }

      debugPrint("جلب المستخدمين المتصلين...");
      final onlineResponse = await _apiService.getOnlineUsers(widget.token);
      debugPrint("تم جلب ${onlineResponse.length} مستخدم متصل");

      debugPrint("جلب إجمالي المستخدمين...");
      final totalResponse = await _apiService.getTotalUsers(widget.token);
      debugPrint("تم جلب $totalResponse إجمالي مستخدم");

      setState(() {
        onlineUsers = onlineResponse.length;
        totalUsers = totalResponse;
        offlineUsers = totalUsers - onlineUsers;
        isLoading = false;
        errorMessage = "";
      });
    } catch (e) {
      debugPrint("خطأ في جلب إحصائيات المستخدمين: $e");
      setState(() {
        isLoading = false;
        errorMessage = "خطأ في جلب البيانات: $e";
      });
    }
  }

  // ===== قياس زمن الاستجابة =====
  Future<void> _fetchPings() async {
    try {
      debugPrint("بدء قياسات زمن الاستجابة...");
      int fbPing = await _pingService.pingHost("facebook.com");
      debugPrint("زمن استجابة فيسبوك: $fbPing");

      int ggPing = await _pingService.pingHost("google.com");
      debugPrint("زمن استجابة جوجل: $ggPing");

      int tkPing = await _pingService.pingHost("tiktok.com");
      debugPrint("زمن استجابة تيك توك: $tkPing");

      setState(() {
        facebookPing = fbPing;
        googlePing = ggPing;
        tiktokPing = tkPing;
      });
    } catch (e) {
      debugPrint("خطأ في قياس زمن الاستجابة: $e");
    }
  }

  // ===== حساب نسبة الاتصال =====
  double _calculatePercentage() {
    if (totalUsers == 0) return 0.0;
    return (onlineUsers / totalUsers).clamp(0.0, 1.0);
  }

  // ===== تهيئة الإشعارات =====
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinInitializationSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: darwinInitializationSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload == 'expired_users') {
          Navigator.push(
            navigatorKey.currentContext!,
            MaterialPageRoute(
              builder: (context) => ExpiredUsersScreen(token: widget.token),
            ),
          );
        }
      },
    );

    await _createNotificationChannels();
  }

  // ===== إنشاء قنوات الإشعارات =====
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel welcomeChannel = AndroidNotificationChannel(
      WELCOME_CHANNEL_ID,
      WELCOME_CHANNEL_NAME,
      description: WELCOME_CHANNEL_DESC,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    const AndroidNotificationChannel subscriptionChannel = AndroidNotificationChannel(
      SUBSCRIPTION_CHANNEL_ID,
      SUBSCRIPTION_CHANNEL_NAME,
      description: SUBSCRIPTION_CHANNEL_DESC,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      sound: RawResourceAndroidNotificationSound('alert_sound'),
    );

    final plugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (plugin != null) {
      await plugin.createNotificationChannel(welcomeChannel);
      await plugin.createNotificationChannel(subscriptionChannel);
    }
  }

  // ===== طلب الأذونات =====
  Future<void> _requestPermissions() async {
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      debugPrint("خطأ في طلب الأذونات: $e");
    }
  }

  // ===== التحقق من أول تسجيل دخول وعرض إشعار الترحيب =====
  Future<void> _checkFirstLoginAndShowWelcomeNotification() async {
    final prefs = await SharedPreferences.getInstance();
    bool isFirstLogin = prefs.getBool('isFirstLogin') ?? true;

    if (isFirstLogin) {
      await Future.delayed(const Duration(seconds: 1));
      await _showWelcomeNotification();
      await prefs.setBool('isFirstLogin', false);
    }
  }

  // ===== عرض إشعار الترحيب =====
  Future<void> _showWelcomeNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      WELCOME_CHANNEL_ID,
      WELCOME_CHANNEL_NAME,
      channelDescription: WELCOME_CHANNEL_DESC,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        'تم تسجيل دخولك بنجاح. سيتم إعلامك فقط عند وجود اشتراكات منتهية جديدة.<br><br>'
        '• اضغط على الإشعار للذهاب إلى التطبيق<br>'
        '• ستظهر التنبيهات فقط عند وجود مستخدمين جدد منتهي اشتراكهم<br>'
        '• يمكنك دائمًا التحقق من حالة المستخدمين داخل التطبيق',
        htmlFormatBigText: true,
        contentTitle: '<b>مرحباً بك في التطبيق</b>',
        htmlFormatContentTitle: true,
        summaryText: 'معلومات مهمة',
        htmlFormatSummaryText: true,
      ),
      color: Colors.green,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      channelShowBadge: true,
      autoCancel: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      1001,
      "مرحباً بك في التطبيق",
      "تم تسجيل دخولك بنجاح. سيتم إعلامك فقط عند وجود اشتراكات منتهية جديدة.",
      platformChannelSpecifics,
      payload: 'welcome_notification',
    );
  }

  // ===== التحقق من المستخدمين المنتهية اشتراكاتهم مرة واحدة =====
  Future<void> _checkExpiredUsersOnce() async {
    try {
      final usersList = await _apiService.getAllUsers(widget.token);
      debugPrint("تم جلب ${usersList.length} مستخدم للتحقق من الاشتراكات المنتهية");

      DateTime now = DateTime.now();
      DateTime todayStart = DateTime(now.year, now.month, now.day);
      DateTime todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final prefs = await SharedPreferences.getInstance();
      Set<String> notifiedUserIds = Set<String>.from(
          prefs.getStringList('notified_expired_users') ?? []);

      List<Map<String, dynamic>> newExpiredUsers = [];

      for (var user in usersList) {
        if (user['expiration'] == null || user['expiration'].toString().isEmpty) {
          continue;
        }

        String userId = user['id']?.toString() ?? user['username']?.toString() ?? '';

        try {
          DateTime expiryDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(user['expiration'].toString());

          if (expiryDate.isAfter(todayStart) &&
              expiryDate.isBefore(todayEnd) &&
              now.isAfter(expiryDate) &&
              !notifiedUserIds.contains(userId)) {

            newExpiredUsers.add(user);
            notifiedUserIds.add(userId);
          }
        } catch (e) {
          debugPrint("خطأ في تحليل تاريخ المستخدم: ${user['username']}: $e");
        }
      }

      await prefs.setStringList('notified_expired_users', notifiedUserIds.toList());

      if (newExpiredUsers.isNotEmpty) {
        debugPrint("تم العثور على ${newExpiredUsers.length} مستخدم جديد منتهي الاشتراك");
        await _showNewExpiredUsersNotification(newExpiredUsers);
      } else {
        debugPrint("لا يوجد مستخدمين جدد منتهي اشتراكهم اليوم");
      }
    } catch (e) {
      debugPrint("خطأ في التحقق من المستخدمين المنتهية اشتراكاتهم: $e");
    }
  }

  // ===== عرض إشعار بالمستخدمين الجدد المنتهية اشتراكاتهم =====
  Future<void> _showNewExpiredUsersNotification(
    List<Map<String, dynamic>> newExpiredUsers,
  ) async {
    if (newExpiredUsers.isNotEmpty) {
      String detailedContent = '';
      for (int i = 0; i < min(newExpiredUsers.length, 5); i++) {
        var user = newExpiredUsers[i];
        String expiryDate = user['expiration']?.toString() ?? 'غير محدد';
        try {
          DateTime expiry = DateFormat("yyyy-MM-dd HH:mm").parse(expiryDate);
          expiryDate = DateFormat("yyyy-MM-dd HH:mm").format(expiry);
        } catch (_) {}

        detailedContent += '<b>${user['username']}</b> - انتهى في $expiryDate<br>';
      }

      if (newExpiredUsers.length > 5) {
        detailedContent += 'و ${newExpiredUsers.length - 5} مستخدمين آخرين...';
      }

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          SUBSCRIPTION_CHANNEL_ID,
          SUBSCRIPTION_CHANNEL_NAME,
          channelDescription: SUBSCRIPTION_CHANNEL_DESC,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            detailedContent,
            htmlFormatBigText: true,
            contentTitle: '<b>انتهاء اشتراكات جديدة</b>',
            htmlFormatContentTitle: true,
            summaryText: '${newExpiredUsers.length} مشترك جديد منتهي',
            htmlFormatSummaryText: true,
          ),
          color: Colors.red,
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          channelShowBadge: true,
          autoCancel: true,
      );

      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      List<String> usernames = newExpiredUsers.map((user) => user['username'].toString()).toList();
      String usersText = usernames.length <= 3
          ? usernames.join('، ')
          : "${usernames.sublist(0, 3).join('، ')} و${usernames.length - 3} آخرين";

      await flutterLocalNotificationsPlugin.show(
        1002,
        "انتهاء اشتراكات جديدة",
        "تم انتهاء اشتراك ${newExpiredUsers.length} مستخدم جديد: $usersText",
        platformChannelSpecifics,
        payload: 'expired_users',
      );
    }
  }

  // ===== الانتقال إلى الشاشات المختلفة =====
  void _navigateToScreen(int index) {
    setState(() {
      _selectedIndex = index;
    });

    Navigator.of(context).pop();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (index == 0) {
        return;
      }

      Widget screenToNavigate;
      switch (index) {
        case 1:
          screenToNavigate = OnlineUsersScreen(token: widget.token);
          break;
        case 2:
          screenToNavigate = AllUsersScreen(token: widget.token);
          break;
        case 3:
          screenToNavigate = ExpiredUsersScreen(token: widget.token);
          break;
        case 4:
          screenToNavigate = const SpeedTestPage();
          break;
        default:
          return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WillPopScope(
            onWillPop: () async {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => Dashboard(token: widget.token),
                ),
              );
              return false;
            },
            child: screenToNavigate,
          ),
        ),
      );
    });
  }

  // ===== عرض مربع حوار تسجيل الخروج =====
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red[300]),
            SizedBox(width: 10),
            Text(
              'تسجيل الخروج',
              style: TextStyle(color: _textColor),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
          style: TextStyle(color: _textColor.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(color: _textColor.withOpacity(0.8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _logout,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('تأكيد الخروج'),
            ),
          ),
        ],
      ),
    );
  }

  // ===== عرض مربع حوار حول التطبيق =====
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: _primaryColor),
            SizedBox(width: 10),
            Text(
              "حول التطبيق",
              style: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.admin_panel_settings,
                size: 40,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "إدارة المشتركين",
              style: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "الإصدار 1.0.0",
              style: TextStyle(
                color: _textColor.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "تطبيق لإدارة المشتركين وعرض حالة اتصالهم ومراقبة انتهاء صلاحية اشتراكاتهم.",
              style: TextStyle(
                color: _textColor.withOpacity(0.9),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  "إغلاق",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== تحديث البيانات يدويًا =====
  Future<void> _manualRefresh() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    debugPrint("جاري تحديث البيانات يدويًا...");

    _initApiService();
    await _fetchData();
    await _checkSubscriptionStatus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("تم تحديث البيانات"),
        backgroundColor: _primaryColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(screenWidth),
      drawer: _buildCustomDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_surfaceColor, _backgroundColor],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _manualRefresh,
          color: _primaryColor,
          backgroundColor: _cardColor,
          child: isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: _secondaryColor),
                      const SizedBox(height: 16),
                      Text(
                        "جاري تحميل البيانات...",
                        style: TextStyle(color: _textColor, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : errorMessage.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            errorMessage,
                            style: const TextStyle(color: Colors.red, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _manualRefresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text("إعادة المحاولة"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildDashboardContent(screenWidth),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ===== بناء القائمة الجانبية المخصصة =====
  Widget _buildCustomDrawer() {
    return CustomDrawer(
      userName: currentUserName,
      userRole: currentUserRole,
      userEmail: currentUserEmail,
      userAvatarUrl: userAvatarUrl,
      onlineUsers: onlineUsers,
      totalUsers: totalUsers,
      offlineUsers: offlineUsers,
      selectedIndex: _selectedIndex,
      onNavigate: _navigateToScreen,
      onLogout: _showLogoutDialog,
      onAboutTap: () {
        Navigator.pop(context);
        _showAboutDialog();
      },
      onSettingsTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('سيتم إضافة صفحة الإعدادات قريباً'),
            backgroundColor: _primaryColor,
          ),
        );
      },
      facebookPing: facebookPing,
      googlePing: googlePing,
      tiktokPing: tiktokPing,
      primaryColor: _primaryColor,
      secondaryColor: _secondaryColor,
      accentColor: _accentColor,
      backgroundColor: _backgroundColor,
      surfaceColor: _surfaceColor,
      cardColor: _cardColor,
      textColor: _textColor,
      extraInfo: '${_apiService.companyName} - ${_apiService.baseUrl.split('/')[2]}',
    );
  }

  // ===== بناء شريط التطبيق المحسن =====
  PreferredSizeWidget _buildAppBar(double screenWidth) {
    return AppBar(
      backgroundColor: _surfaceColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        "لوحة التحكم",
        style: TextStyle(
          color: _textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: _manualRefresh,
          icon: Icon(Icons.refresh, color: _primaryColor),
          tooltip: "تحديث البيانات",
        ),
        GestureDetector(
          onTap: _showAboutDialog,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.info_outline,
              color: _primaryColor,
              size: 24,
            ),
          ),
        ),
      ],
      leading: GestureDetector(
        onTap: () {
          _scaffoldKey.currentState?.openDrawer();
        },
        child: Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.menu,
            color: _primaryColor,
          ),
        ),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_backgroundColor, _surfaceColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }

  // ===== بناء شريط التنقل السفلي =====
  Widget _buildBottomBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: _surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomNavItem(0, Icons.dashboard, "الرئيسية"),
          _buildBottomNavItem(1, Icons.people, "المتصلون"),
          _buildBottomNavItem(2, Icons.group, "المستخدمون"),
          _buildBottomNavItem(3, Icons.warning, "المنتهي"),
          _buildBottomNavItem(4, Icons.speed, "السرعة"),
        ],
      ),
    );
  }

  // ===== بناء عنصر شريط التنقل السفلي =====
  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _navigateToScreen(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? _primaryColor : _textColor.withOpacity(0.7),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _primaryColor : _textColor.withOpacity(0.7),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== بناء محتوى لوحة التحكم الرئيسية =====
  Widget _buildDashboardContent(double screenWidth) {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  "حالة الاتصال",
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: -0.5, end: 0, curve: Curves.easeOut),
                SizedBox(height: 20),
                CircularPercentIndicator(
                  radius: screenWidth * 0.28,
                  lineWidth: 12.0,
                  percent: _calculatePercentage(),
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "$onlineUsers",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _secondaryColor,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), curve: Curves.easeOut),
                      SizedBox(height: 6),
                      Text(
                        "متصل",
                        style: TextStyle(fontSize: 18, color: _textColor),
                      )
                          .animate()
                          .fadeIn(duration: 600.ms),
                      SizedBox(height: 6),
                      Text(
                        "$onlineUsers / $totalUsers",
                        style: TextStyle(fontSize: 16, color: _textColor.withOpacity(0.7)),
                      )
                          .animate()
                          .fadeIn(duration: 700.ms),
                    ],
                  ),
                  progressColor: _secondaryColor,
                  backgroundColor: Colors.grey.shade800,
                )
                    .animate()
                    .fadeIn(duration: 800.ms)
                    .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOut),
              ],
            ),
          ),
          SizedBox(height: 30),
          _buildInfoCards(screenWidth),
          SizedBox(height: 20),
          _buildNetworkCard(screenWidth),
          SizedBox(height: 20),
          _buildConnectionInfoCard(),
          SizedBox(height: 20),
          Center(
            child: Text(
              "آخر تحديث: ${DateFormat('HH:mm:ss', 'ar').format(lastUpdateTime)}",
              style: TextStyle(
                color: _textColor.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== بناء بطاقات المعلومات لإحصائيات المستخدم =====
  Widget _buildInfoCards(double screenWidth) {
    final double cardPadding = 16;
    final double cardWidth = (screenWidth - cardPadding * 4) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "إحصائيات المستخدمين",
          style: TextStyle(
            color: _textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoCard(
              title: "متصل",
              value: onlineUsers,
              icon: Icons.people,
              color: _secondaryColor,
              width: cardWidth,
            ),
            _buildInfoCard(
              title: "غير متصل",
              value: offlineUsers,
              icon: Icons.person_off,
              color: Colors.grey,
              width: cardWidth,
            ),
          ],
        ),
        SizedBox(height: cardPadding),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoCard(
              title: "الإجمالي",
              value: totalUsers,
              icon: Icons.group,
              color: _primaryColor,
              width: cardWidth,
            ),
            _buildPercentCard(
              title: "نسبة الاتصال",
              percent: _calculatePercentage() * 100,
              icon: Icons.percent,
              color: _accentColor,
              width: cardWidth,
            ),
          ],
        ),
      ],
    );
  }

  // ===== بناء بطاقة معلومات للأرقام =====
  Widget _buildInfoCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _textColor.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            value.toString(),
            style: TextStyle(
              color: _textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: value > 0 ? 1.0 : 0.0,
            backgroundColor: _cardColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.2, end: 0);
  }

  // ===== بناء بطاقة معلومات للنسب المئوية =====
  Widget _buildPercentCard({
    required String title,
    required double percent,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _textColor.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            "${percent.toStringAsFixed(1)}%",
            style: TextStyle(
              color: _textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: percent / 100,
            backgroundColor: _cardColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.2, end: 0);
  }

  // ===== بناء بطاقة سرعة الشبكة =====
  Widget _buildNetworkCard(double screenWidth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.network_check,
                color: _primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                "سرعة الاتصال",
                style: TextStyle(
                  color: _textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNetworkItem("فيسبوك", facebookPing, Icons.facebook),
              _buildNetworkItem("جوجل", googlePing, Icons.search),
              _buildNetworkItem("تيك توك", tiktokPing, Icons.music_video),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 800.ms)
        .slideY(begin: 0.3, end: 0);
  }

  // ===== بناء عنصر سرعة الشبكة =====
  Widget _buildNetworkItem(String name, int ping, IconData icon) {
    String status;
    Color color;

    if (ping < 0) {
      status = "غير متصل";
      color = Colors.red;
    } else if (ping < 100) {
      status = "ممتاز";
      color = _secondaryColor;
    } else if (ping < 200) {
      status = "جيد";
      color = _accentColor;
    } else {
      status = "بطيء";
      color = Colors.red;
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _cardColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: _textColor,
            size: 24,
          ),
        ),
        SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: _textColor,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Text(
          ping >= 0 ? "$ping ms" : "--",
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ===== بناء بطاقة معلومات الاتصال =====
  Widget _buildConnectionInfoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: _primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.link,
                color: _primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                "معلومات الاتصال",
                style: TextStyle(
                  color: _textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildInfoRow("الشركة:", _apiService.companyName),
          _buildInfoRow("الخادم:", _apiService.baseUrl.split('/')[2]),
          _buildInfoRow("حالة الاتصال:", errorMessage.isEmpty ? "متصل" : "غير متصل"),
          _buildInfoRow("حالة التوكن:", "يتم تجديده تلقائياً كل 50 دقيقة"),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 800.ms)
        .slideY(begin: 0.3, end: 0);
  }

  // ===== بناء صف معلومات الاتصال =====
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _textColor.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _textColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}