import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:loginsignup_new/services/api_service.dart';
import 'package:loginsignup_new/services/auth_service.dart';

// معرّف وظيفة العمل في الخلفية
const String TOKEN_REFRESH_TASK = "token_refresh_task";

// خدمة تجديد التوكن مع دعم العمل في الخلفية
class TokenRefreshService {
  // إعدادات مؤقت التجديد - 50 دقيقة بدلاً من ساعة كاملة للأمان
  static const int refreshIntervalMinutes = 50;
  
  // معرّف إرسال واستقبال الرسائل في خلفية التطبيق
  static const String BACKGROUND_PORT_NAME = "token_refresh_port";
  
  // متغيرات حالة الخدمة
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  
  // الحفاظ على نسخة واحدة من الخدمة (Singleton)
  static final TokenRefreshService _instance = TokenRefreshService._internal();
  
  // المنشئ الداخلي
  TokenRefreshService._internal();
  
  // الدالة المصنعة لإرجاع النسخة الوحيدة
  factory TokenRefreshService() {
    return _instance;
  }
  
  // تسجيل مهمة تجديد التوكن في الخلفية
  Future<void> _registerBackgroundTask() async {
    try {
      // تسجيل المهمة الدورية باستخدام Workmanager
      await Workmanager().registerPeriodicTask(
        TOKEN_REFRESH_TASK,
        TOKEN_REFRESH_TASK,
        frequency: Duration(minutes: refreshIntervalMinutes),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: Duration(minutes: 5),
      );
      
      debugPrint("🔄✅ تم تسجيل مهمة تجديد التوكن في الخلفية");
    } catch (e) {
      debugPrint("🔄❌ خطأ في تسجيل مهمة تجديد التوكن في الخلفية: $e");
    }
  }
  
  // إلغاء مهمة تجديد التوكن في الخلفية
  Future<void> _cancelBackgroundTask() async {
    try {
      await Workmanager().cancelByUniqueName(TOKEN_REFRESH_TASK);
      debugPrint("🔄✅ تم إلغاء مهمة تجديد التوكن في الخلفية");
    } catch (e) {
      debugPrint("🔄❌ خطأ في إلغاء مهمة تجديد التوكن في الخلفية: $e");
    }
  }
  
  // بدء خدمة تجديد التوكن التلقائي
  Future<void> startAutoRefresh() async {
    debugPrint("🔄 بدء خدمة تجديد التوكن التلقائي كل $refreshIntervalMinutes دقيقة");
    
    // إلغاء أي مؤقت سابق
    _stopRefreshTimer();
    
    // تسجيل منفذ لتلقي الرسائل من الخلفية
    _registerBackgroundPort();
    
    // تسجيل مهمة التجديد في الخلفية
    await _registerBackgroundTask();
    
    // إنشاء مؤقت جديد للتجديد عندما يكون التطبيق في المقدمة
    _refreshTimer = Timer.periodic(
      Duration(minutes: refreshIntervalMinutes),
      (_) => _refreshToken(),
    );
    
    // تنفيذ تجديد فوري للتوكن
    await _refreshToken();
  }
  
  // إيقاف خدمة تجديد التوكن التلقائي
  Future<void> stopAutoRefresh() async {
    debugPrint("🔄🛑 إيقاف خدمة تجديد التوكن التلقائي");
    
    // إلغاء المؤقت
    _stopRefreshTimer();
    
    // إلغاء المهمة في الخلفية
    await _cancelBackgroundTask();
    
    // إلغاء تسجيل منفذ استقبال الرسائل
    _unregisterBackgroundPort();
  }
  
  // تسجيل منفذ لاستقبال الرسائل من خلفية التطبيق
  void _registerBackgroundPort() {
    try {
      // إنشاء منفذ استقبال
      final receivePort = ReceivePort();
      
      // تسجيل المنفذ باسم معروف
      if (IsolateNameServer.registerPortWithName(
        receivePort.sendPort, 
        BACKGROUND_PORT_NAME
      )) {
        debugPrint("🔄✅ تم تسجيل منفذ استقبال رسائل تجديد التوكن");
        
        // الاستماع للرسائل
        receivePort.listen((message) {
          debugPrint("🔄📨 تم استلام رسالة من الخلفية: $message");
          
          // إذا كانت الرسالة تطلب تجديد التوكن
          if (message == "refresh_token") {
            _refreshToken();
          }
        });
      } else {
        debugPrint("🔄❌ فشل تسجيل منفذ استقبال رسائل تجديد التوكن");
      }
    } catch (e) {
      debugPrint("🔄❌ خطأ في تسجيل منفذ استقبال الرسائل: $e");
    }
  }
  
  // إلغاء تسجيل منفذ استقبال الرسائل
  void _unregisterBackgroundPort() {
    try {
      // إلغاء تسجيل المنفذ
      if (IsolateNameServer.removePortNameMapping(BACKGROUND_PORT_NAME)) {
        debugPrint("🔄✅ تم إلغاء تسجيل منفذ استقبال رسائل تجديد التوكن");
      } else {
        debugPrint("🔄❌ فشل إلغاء تسجيل منفذ استقبال رسائل تجديد التوكن");
      }
    } catch (e) {
      debugPrint("🔄❌ خطأ في إلغاء تسجيل منفذ استقبال الرسائل: $e");
    }
  }
  
  // إيقاف المؤقت الحالي
  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
  
  // تنفيذ عملية تجديد التوكن
  Future<bool> _refreshToken() async {
    // تجنب التداخل في حالة استمرار عملية تجديد سابقة
    if (_isRefreshing) {
      debugPrint("🔄⚠️ تم تجاهل طلب تجديد التوكن (قيد التنفيذ بالفعل)");
      return false;
    }
    
    _isRefreshing = true;
    debugPrint("🔄🔑 بدء عملية تجديد التوكن");
    
    try {
      // الحصول على بيانات المستخدم المخزنة
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      final companyType = prefs.getString('company_type');
      final password = prefs.getString('user_password');
      
      if (username == null || username.isEmpty || 
          companyType == null || companyType.isEmpty ||
          password == null || password.isEmpty) {
        debugPrint("🔄⚠️ لا يمكن تجديد التوكن: بيانات المستخدم غير متوفرة");
        _isRefreshing = false;
        return false;
      }
      
      // إنشاء ApiService بناءً على اسم الشركة
      final apiService = ApiService.byName(companyType);
      
      // محاولة تسجيل الدخول للحصول على توكن جديد
      final result = await apiService.login(username, password);
      
      if (result != null && (result["status"] == 200 || result.containsKey("token"))) {
        final newToken = result["token"] ?? "";
        final userId = result["id"] ?? "";
        
        // حفظ التوكن الجديد
        await AuthService.saveUserSession(
          token: newToken,
          username: username,
          companyType: companyType,
          userId: userId.toString(),
          password: password, // إعادة حفظ كلمة المرور للتجديدات المستقبلية
        );
        
        debugPrint("🔄✅ تم تجديد التوكن بنجاح");
        _isRefreshing = false;
        return true;
      } else {
        debugPrint("🔄❌ فشل تجديد التوكن: ${result?.toString() ?? 'لا توجد استجابة'}");
        _isRefreshing = false;
        return false;
      }
    } catch (e) {
      debugPrint("🔄❌ خطأ أثناء تجديد التوكن: $e");
      _isRefreshing = false;
      return false;
    }
  }
  
  // تنفيذ تجديد فوري للتوكن (يمكن استدعاؤها عند الحاجة)
  Future<bool> forceRefreshNow() async {
    if (_isRefreshing) {
      debugPrint("🔄⚠️ التوكن قيد التجديد بالفعل");
      return false;
    }
    
    // إعادة ضبط المؤقت إذا كان نشطًا
    if (_refreshTimer != null) {
      _stopRefreshTimer();
      _refreshTimer = Timer.periodic(
        Duration(minutes: refreshIntervalMinutes),
        (_) => _refreshToken(),
      );
    }
    
    // تنفيذ التجديد
    return await _refreshToken();
  }
  
  // التحقق من حالة الخدمة
  bool get isActive => _refreshTimer != null;
}

// دالة معالجة مهام الخلفية - يجب استدعاؤها عند إعداد التطبيق
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint("🔄🔙 تنفيذ مهمة الخلفية: $task");
    
    if (task == TOKEN_REFRESH_TASK) {
      try {
        // محاولة إرسال رسالة للتطبيق إذا كان في المقدمة
        SendPort? sendPort = IsolateNameServer.lookupPortByName(TokenRefreshService.BACKGROUND_PORT_NAME);
        if (sendPort != null) {
          sendPort.send("refresh_token");
          debugPrint("🔄✅ تم إرسال طلب تجديد التوكن للتطبيق");
        } else {
          debugPrint("🔄ℹ️ التطبيق غير نشط، تنفيذ تجديد التوكن في الخلفية");
          
          // تنفيذ عملية تجديد التوكن مباشرة من الخلفية
          final prefs = await SharedPreferences.getInstance();
          final username = prefs.getString('username');
          final companyType = prefs.getString('company_type');
          final password = prefs.getString('user_password');
          
          if (username != null && companyType != null && password != null) {
            final apiService = ApiService.byName(companyType);
            final result = await apiService.login(username, password);
            
            if (result != null && result.containsKey("token")) {
              final newToken = result["token"] ?? "";
              final userId = result["id"] ?? "";
              
              // حفظ التوكن الجديد
              await prefs.setString('authToken', newToken);
              await prefs.setString('api_token', newToken);
              
              debugPrint("🔄✅ تم تجديد التوكن في الخلفية بنجاح");
              return true;
            }
          }
        }
      } catch (e) {
        debugPrint("🔄❌ خطأ في مهمة تجديد التوكن في الخلفية: $e");
      }
    }
    
    return true;
  });
}