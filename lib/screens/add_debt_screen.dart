import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/debt_model.dart';
import '../services/database_service.dart';

class AddDebtScreen extends StatefulWidget {
  final String token;
  final int? userId;
  final String? username;

  const AddDebtScreen({
    Key? key, 
    required this.token, 
    this.userId, 
    this.username,
  }) : super(key: key);

  @override
  _AddDebtScreenState createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _databaseService = DatabaseService.instance;
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  DateTime _dueDate = DateTime.now().add(Duration(days: 30));
  bool _isSubmitting = false;
  
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
    
    // تعبئة البيانات إذا تم تمريرها
    if (widget.username != null) {
      _usernameController.text = widget.username!;
    }
    
    _dueDateController.text = DateFormat('yyyy/MM/dd').format(_dueDate);
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    _amountController.dispose();
    _dueDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              onSurface: _textColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
        _dueDateController.text = DateFormat('yyyy/MM/dd').format(_dueDate);
      });
    }
  }
  
  Future<void> _saveDebt() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });
      
      try {
        final double amount = double.parse(_amountController.text);
        
        final debt = DebtModel(
          userId: widget.userId ?? 0, // استخدم 0 إذا لم يتم تمرير معرف المستخدم
          username: _usernameController.text,
          amount: amount,
          dueDate: _dueDate,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );
        
        await _databaseService.addDebt(debt);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("تم إضافة الدين بنجاح"),
            backgroundColor: _accentColor,
          ),
        );
        
        Navigator.pop(context, true); // إرجاع قيمة true للإشارة إلى نجاح العملية
      } catch (e) {
        print("خطأ في حفظ الدين: $e");
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("حدث خطأ أثناء حفظ الدين"),
            backgroundColor: Colors.red,
          ),
        );
        
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          "إضافة دين جديد",
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
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(),
                const SizedBox(height: 24),
                _buildFormSection(),
                const SizedBox(height: 32),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: _primaryColor,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "إضافة سجل دين جديد",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "يرجى إدخال بيانات الدين بما في ذلك اسم المستخدم والمبلغ وتاريخ الاستحقاق.",
                  style: TextStyle(
                    fontSize: 14,
                    color: _textColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("معلومات المستخدم"),
        const SizedBox(height: 16),
        TextFormField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: "اسم المستخدم",
            hintText: "أدخل اسم المستخدم",
            prefixIcon: Icon(Icons.person, color: _primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "يرجى إدخال اسم المستخدم";
            }
            return null;
          },
          readOnly: widget.username != null, // جعل الحقل للقراءة فقط إذا تم تمرير اسم المستخدم
        ),
        const SizedBox(height: 24),
        
        _buildSectionTitle("تفاصيل الدين"),
        const SizedBox(height: 16),
        TextFormField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: "المبلغ",
            hintText: "أدخل المبلغ المستحق",
            prefixIcon: Icon(Icons.attach_money, color: _primaryColor),
            suffixText: "ر.س",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "يرجى إدخال المبلغ";
            }
            if (double.tryParse(value) == null) {
              return "يرجى إدخال رقم صحيح";
            }
            if (double.parse(value) <= 0) {
              return "يجب أن يكون المبلغ أكبر من صفر";
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _dueDateController,
              decoration: InputDecoration(
                labelText: "تاريخ الاستحقاق",
                hintText: "اختر تاريخ الاستحقاق",
                prefixIcon: Icon(Icons.calendar_today, color: _primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "يرجى اختيار تاريخ الاستحقاق";
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: "ملاحظات",
            hintText: "أدخل أي ملاحظات إضافية (اختياري)",
            prefixIcon: Icon(Icons.note, color: _primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          maxLines: 3,
        ),
      ],
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _saveDebt,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isSubmitting
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save),
                  const SizedBox(width: 8),
                  Text(
                    "حفظ الدين",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}