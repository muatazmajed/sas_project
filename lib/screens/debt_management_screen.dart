import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/debt_model.dart';
import '../services/database_service.dart';
import 'add_debt_screen.dart';

class DebtManagementScreen extends StatefulWidget {
  final String token;

  const DebtManagementScreen({Key? key, required this.token}) : super(key: key);

  @override
  _DebtManagementScreenState createState() => _DebtManagementScreenState();
}

class _DebtManagementScreenState extends State<DebtManagementScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  bool isLoading = true;
  List<DebtModel> allDebts = [];
  List<DebtModel> filteredDebts = [];
  double totalUnpaid = 0.0;
  String sortOption = 'dueDate'; // خيار الترتيب الافتراضي حسب تاريخ الاستحقاق

  // ألوان التطبيق
  final Color _primaryColor = const Color(0xFFFF6B35);
  final Color _secondaryColor = const Color(0xFFF9F2E7);
  final Color _accentColor = const Color(0xFF2EC4B6);
  final Color _backgroundColor = Colors.white;
  final Color _cardColor = const Color(0xFFFFF9F1);
  final Color _textColor = Colors.black87;

  @override
  void initState() {
    super.initState();
    _loadDebts();
  }

  Future<void> _loadDebts() async {
    setState(() {
      isLoading = true;
    });

    try {
      // جلب جميع الديون من قاعدة البيانات
      final allDebtsFromDb = await _databaseService.getAllDebts();

      // فلترة الديون غير المسددة فقط
      final unPaidDebts = allDebtsFromDb.where((debt) => !debt.isPaid).toList();

      // حساب إجمالي الديون غير المسددة
      final total = await _databaseService.getTotalUnpaidDebts();

      setState(() {
        // تعيين قائمة الديون بالديون غير المسددة فقط
        allDebts = unPaidDebts;
        filteredDebts = unPaidDebts;
        totalUnpaid = total;
        isLoading = false;
        // ترتيب الديون بعد تحميلها
        _sortDebts();
      });
    } catch (e) {
      print("خطأ في تحميل الديون: $e");
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar("حدث خطأ أثناء تحميل الديون");
    }
  }

  void _filterDebts(String query) {
    setState(() {
      filteredDebts = allDebts.where((debt) {
        return debt.username.toLowerCase().contains(query.toLowerCase()) ||
               (debt.notes != null && debt.notes!.toLowerCase().contains(query.toLowerCase()));
      }).toList();
      _sortDebts(); // حفظ الترتيب بعد الفلترة
    });
  }

  // دالة جديدة للترتيب
  void _sortDebts() {
    setState(() {
      switch (sortOption) {
        case 'dueDate':
          filteredDebts.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          break;
        case 'amount':
          filteredDebts.sort((a, b) => b.amount.compareTo(a.amount));
          break;
        case 'name':
          filteredDebts.sort((a, b) => a.username.compareTo(b.username));
          break;
      }
    });
  }

  // دالة مساعدة لعرض رسائل الخطأ
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // دالة مساعدة لعرض رسائل النجاح
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _accentColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _markAsPaid(DebtModel debt) async {
    try {
      await _databaseService.updateDebtStatus(debt.id!, true);

      // تحديث القائمة مباشرة بإزالة الدين المسدد
      setState(() {
        allDebts.removeWhere((item) => item.id == debt.id);
        filteredDebts.removeWhere((item) => item.id == debt.id);
      });

      // إعادة حساب إجمالي الديون غير المسددة
      final total = await _databaseService.getTotalUnpaidDebts();
      setState(() {
        totalUnpaid = total;
      });

      _showSuccessSnackBar("تم تسديد الدين بنجاح");
    } catch (e) {
      print("خطأ في تحديث حالة الدين: $e");
      _showErrorSnackBar("حدث خطأ أثناء تحديث حالة الدين");
    }
  }

  // إضافة دالة لعرض مربع حوار تأكيد
  Future<void> _showConfirmationDialog(DebtModel debt) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('تأكيد العملية'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('هل أنت متأكد من رغبتك في تسديد هذا الدين؟'),
                Text(
                  'المبلغ: ${debt.amount.toStringAsFixed(2)} د.ع',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('إلغاء'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
              ),
              child: Text('تأكيد'),
              onPressed: () {
                Navigator.of(context).pop();
                _markAsPaid(debt);
              },
            ),
          ],
        );
      },
    );
  }

  // إضافة دالة لعرض مربع حوار خيارات الترتيب
  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ترتيب حسب',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.calendar_today,
                color: sortOption == 'dueDate' ? _primaryColor : Colors.grey,
              ),
              title: Text('تاريخ الاستحقاق'),
              selected: sortOption == 'dueDate',
              onTap: () {
                setState(() {
                  sortOption = 'dueDate';
                  _sortDebts();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.attach_money,
                color: sortOption == 'amount' ? _primaryColor : Colors.grey,
              ),
              title: Text('المبلغ (من الأعلى للأقل)'),
              selected: sortOption == 'amount',
              onTap: () {
                setState(() {
                  sortOption = 'amount';
                  _sortDebts();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.sort_by_alpha,
                color: sortOption == 'name' ? _primaryColor : Colors.grey,
              ),
              title: Text('اسم المستخدم (أبجديًا)'),
              selected: sortOption == 'name',
              onTap: () {
                setState(() {
                  sortOption = 'name';
                  _sortDebts();
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          "إدارة الديون",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        actions: [
          // إضافة زر الترتيب
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.white),
            tooltip: 'ترتيب الديون',
            onPressed: _showSortOptions,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'تحديث البيانات',
            onPressed: _loadDebts,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(),
          _buildSearchBar(),
          // عرض مؤشر التحميل في قسم منفصل
          if (isLoading)
            Container(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: CircularProgressIndicator(color: _primaryColor),
              ),
            ),
          Expanded(
            child: isLoading
                ? Center(child: Text("جاري تحميل البيانات..."))
                : filteredDebts.isEmpty
                    ? _buildEmptyState()
                    : _buildDebtList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accentColor,
        icon: Icon(Icons.add),
        label: Text("إضافة دين جديد"),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddDebtScreen(token: widget.token),
            ),
          );

          if (result == true) {
            _loadDebts();
          }
        },
        tooltip: 'إضافة دين جديد',
      ),
    );
  }

  Widget _buildSummaryCard() {
    // حساب عدد الديون المتأخرة
    final overdueDebts = allDebts.where((debt) => debt.dueDate.isBefore(DateTime.now())).length;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "إجمالي الديون المستحقة:",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${totalUnpaid.toStringAsFixed(2)} د.ع",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "عدد الديون غير المسددة:",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
              Text(
                "${allDebts.length}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // إضافة عرض عدد الديون المتأخرة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ديون متأخرة:",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: overdueDebts > 0 ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$overdueDebts",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: "البحث عن مستخدم أو ملاحظات...",
          prefixIcon: Icon(Icons.search, color: _primaryColor),
          suffixIcon: Icon(Icons.filter_list, color: _primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primaryColor),
          ),
          filled: true,
          fillColor: _secondaryColor,
        ),
        onChanged: _filterDebts,
      ),
    );
  }

  Widget _buildDebtList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredDebts.length,
      itemBuilder: (context, index) {
        final debt = filteredDebts[index];
        return _buildDebtCard(debt);
      },
    );
  }

  Widget _buildDebtCard(DebtModel debt) {
    final isPastDue = debt.dueDate.isBefore(DateTime.now());
    // حساب الأيام المتبقية للاستحقاق
    final daysLeft = debt.dueDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPastDue
            ? BorderSide(color: Colors.red, width: 1)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _primaryColor,
                  radius: 20,
                  child: Text(
                    debt.username.isNotEmpty ? debt.username[0].toUpperCase() : "?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.username,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      Text(
                        "تاريخ الإنشاء: ${DateFormat('yyyy/MM/dd').format(debt.createdAt)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPastDue
                        ? Colors.red.withOpacity(0.2)
                        : daysLeft <= 7 && daysLeft >= 0
                            ? Colors.amber.withOpacity(0.2)
                            : _primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPastDue 
                        ? "متأخر" 
                        : daysLeft <= 7 && daysLeft >= 0
                            ? "قريب"
                            : "مستحق",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isPastDue
                          ? Colors.red
                          : daysLeft <= 7 && daysLeft >= 0
                              ? Colors.amber.shade800
                              : _primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _secondaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "المبلغ المستحق:",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        "${debt.amount.toStringAsFixed(2)} د.ع",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "تاريخ الاستحقاق:",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            DateFormat('yyyy/MM/dd').format(debt.dueDate),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isPastDue ? Colors.red : _textColor,
                            ),
                          ),
                          // إضافة مؤشر للأيام المتبقية
                          if (!isPastDue && daysLeft <= 14)
                            Container(
                              margin: EdgeInsets.only(left: 4),
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: daysLeft <= 3
                                    ? Colors.red.withOpacity(0.2)
                                    : daysLeft <= 7
                                        ? Colors.amber.withOpacity(0.2)
                                        : Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "متبقي $daysLeft يوم",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: daysLeft <= 3
                                      ? Colors.red
                                      : daysLeft <= 7
                                          ? Colors.amber.shade800
                                          : Colors.green,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (debt.notes != null && debt.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              // تحسين عرض الملاحظات باستخدام ExpansionTile
              ExpansionTile(
                title: Text(
                  "ملاحظات",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      debt.notes!,
                      style: TextStyle(
                        fontSize: 14,
                        color: _textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // زر تسديد الدين
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showConfirmationDialog(debt),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text("تسديد الدين"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                // إضافة زر الإشعارات
                SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    _showSuccessSnackBar("تم إرسال تذكير للعميل");
                  },
                  icon: Icon(Icons.notifications_active),
                  tooltip: "إرسال تذكير",
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.money_off,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "لا توجد ديون مسجلة",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "سيتم عرض الديون المسجلة للمشتركين هنا",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // إضافة زر للإضافة في حالة عدم وجود بيانات
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text("إضافة دين جديد"),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddDebtScreen(token: widget.token),
                ),
              );

              if (result == true) {
                _loadDebts();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}