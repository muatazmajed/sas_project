import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class CustomDrawer extends StatelessWidget {
  final String userName;
  final String userRole;
  final String userEmail;
  final String? userAvatarUrl;
  final int onlineUsers;
  final int totalUsers;
  final int offlineUsers;
  final int selectedIndex;
  final Function(int) onNavigate;
  final VoidCallback onLogout;
  final VoidCallback onAboutTap;
  final VoidCallback onSettingsTap;
  final int facebookPing;
  final int googlePing;
  final int tiktokPing;
  final String extraInfo;
  
  // ألوان التطبيق
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color cardColor;
  final Color textColor;

  const CustomDrawer({
    Key? key,
    required this.userName,
    required this.userRole,
    required this.userEmail,
    this.userAvatarUrl,
    required this.onlineUsers,
    required this.totalUsers,
    required this.offlineUsers,
    required this.selectedIndex,
    required this.onNavigate,
    required this.onLogout,
    required this.onAboutTap,
    required this.onSettingsTap,
    required this.facebookPing,
    required this.googlePing,
    required this.tiktokPing,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.cardColor,
    required this.textColor, 
    required this.extraInfo,
  }) : super(key: key);

  // حساب نسبة المستخدمين المتصلين
  double _calculatePercentage() {
    if (totalUsers == 0) return 0.0;
    return (onlineUsers / totalUsers).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    // تحديد قياسات مناسبة
    final double drawerWidth = screenWidth * 0.75;
    final double itemHeight = screenHeight * 0.05;
    final double iconSize = screenHeight * 0.022;
    final double fontSize = screenHeight * 0.014;
    final double dividerPadding = screenHeight * 0.008;
    
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        bottomLeft: Radius.circular(20),
      ),
      child: Drawer(
        backgroundColor: Colors.transparent,
        width: drawerWidth,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                backgroundColor.withOpacity(0.95),
                surfaceColor.withOpacity(0.95),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // رأس الدراور المحسن
                _buildEnhancedHeader(screenWidth, screenHeight),
                
                // قسم المعلومات
                _buildCompanyInfoSection(screenWidth, screenHeight),
                
                // القوائم
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        
                        // قسم لوحة التحكم
                        _buildSectionTitle("لوحة التحكم", fontSize),
                        _buildMenuItem(
                          index: 0,
                          title: "الرئيسية",
                          icon: Icons.dashboard_rounded,
                          itemHeight: itemHeight,
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        
                        // فاصل
                        _buildDivider(dividerPadding),
                        
                        // قسم المستخدمين
                        _buildSectionTitle("المستخدمين", fontSize),
                        _buildMenuItem(
                          index: 2,
                          title: "جميع المستخدمين",
                          icon: Icons.people,
                          badge: totalUsers,
                          badgeColor: primaryColor,
                          itemHeight: itemHeight,
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        _buildMenuItem(
                          index: 1,
                          title: "المستخدمون المتصلون",
                          icon: Icons.person,
                          badge: onlineUsers,
                          badgeColor: secondaryColor,
                          itemHeight: itemHeight,
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        _buildMenuItem(
                          index: 3,
                          title: "المنتهي اشتراكهم",
                          icon: Icons.warning_amber_rounded,
                          badge: offlineUsers,
                          badgeColor: Colors.red[400],
                          itemHeight: itemHeight,
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        
                        // فاصل
                        _buildDivider(dividerPadding),
                        
                        // قسم الأدوات
                        _buildSectionTitle("الأدوات", fontSize),
                        _buildMenuItem(
                          index: 4,
                          title: "اختبار سرعة الإنترنت",
                          icon: Icons.speed,
                          itemHeight: itemHeight,
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        
                        // فاصل
                        _buildDivider(dividerPadding),
                        
                        // قسم البنق
                        _buildSectionTitle("سرعة الاتصال", fontSize),
                        _buildPingCard(screenWidth),
                        
                        // فاصل
                        _buildDivider(dividerPadding),
                        
                        // قسم الإعدادات
                        _buildSectionTitle("الإعدادات", fontSize),
                        _buildCustomMenuItem(
                          title: "إعدادات التطبيق",
                          icon: Icons.settings,
                          onTap: onSettingsTap,
                          itemHeight: itemHeight,
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        _buildCustomMenuItem(
                          title: "حول التطبيق",
                          icon: Icons.info_outline,
                          onTap: onAboutTap,
                          itemHeight: itemHeight,
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),

                        // إضافة قسم معلومات النظام
                        _buildDivider(dividerPadding),
                        _buildSystemInfo(fontSize),
                        
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                
                // زر تسجيل الخروج
                _buildLogoutButton(fontSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // رأس محسن للدرور
  Widget _buildEnhancedHeader(double screenWidth, double screenHeight) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.02,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // معلومات المستخدم
          Row(
            children: [
              // صورة المستخدم
              Container(
                width: screenWidth * 0.14,
                height: screenWidth * 0.14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  color: Colors.white.withOpacity(0.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: userAvatarUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(screenWidth * 0.07),
                        child: Image.network(
                          userAvatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, error, _) => Center(
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : "U",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.06,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          userName.isNotEmpty
                              ? userName[0].toUpperCase()
                              : "U",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              SizedBox(width: 12),
              
              // اسم المستخدم ومعلوماته
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenHeight * 0.02,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      userRole,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: screenHeight * 0.014,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (userEmail.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(
                        userEmail,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: screenHeight * 0.012,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // قسم جديد لمعلومات الشركة
  Widget _buildCompanyInfoSection(double screenWidth, double screenHeight) {
    final percentValue = _calculatePercentage();
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.015,
      ),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // عنوان القسم
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: primaryColor,
                size: screenHeight * 0.02,
              ),
              SizedBox(width: 8),
              Text(
                "معلومات الاتصال",
                style: TextStyle(
                  color: textColor,
                  fontSize: screenHeight * 0.016,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 10),
          
          // معلومات الخادم والشركة
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.business,
                  color: primaryColor,
                  size: screenHeight * 0.018,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      extraInfo,
                      style: TextStyle(
                        color: textColor,
                        fontSize: screenHeight * 0.013,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // دائرة نسبة المستخدمين المتصلين
          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircularPercentIndicator(
                  radius: screenHeight * 0.024,
                  lineWidth: 4,
                  percent: percentValue,
                  center: Text(
                    "${(percentValue * 100).toInt()}%",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: screenHeight * 0.011,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  progressColor: secondaryColor,
                  backgroundColor: cardColor.withOpacity(0.3),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "المستخدمون المتصلون",
                        style: TextStyle(
                          color: textColor,
                          fontSize: screenHeight * 0.014,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "$onlineUsers من أصل $totalUsers مشترك",
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: screenHeight * 0.012,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // إضافة قسم معلومات النظام
  Widget _buildSystemInfo(double fontSize) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: textColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: primaryColor,
                size: 14,
              ),
              SizedBox(width: 6),
              Text(
                "معلومات النظام",
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildInfoRow("الشركة", extraInfo.split(' - ')[0], fontSize),
          _buildInfoRow("الخادم", extraInfo.split(' - ').length > 1 ? extraInfo.split(' - ')[1] : "", fontSize),
          _buildInfoRow("الإصدار", "1.0.0", fontSize),
        ],
      ),
    );
  }

  // بناء صف معلومات لقسم معلومات النظام
  Widget _buildInfoRow(String label, String value, double fontSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label + ":",
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: fontSize * 0.9,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize * 0.9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // بناء عنصر قائمة
  Widget _buildMenuItem({
    required int index,
    required String title,
    required IconData icon,
    dynamic badge,
    Color? badgeColor,
    required double itemHeight,
    required double iconSize,
    required double fontSize,
  }) {
    final bool isSelected = index == selectedIndex;
    
    return GestureDetector(
      onTap: () => onNavigate(index),
      child: Container(
        height: itemHeight,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: primaryColor.withOpacity(0.3), width: 1)
              : null,
        ),
        child: Row(
          children: [
            // أيقونة العنصر
            Container(
              width: itemHeight * 0.7,
              height: itemHeight * 0.7,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withOpacity(0.2)
                    : cardColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? primaryColor : textColor.withOpacity(0.7),
                size: iconSize,
              ),
            ),
            
            // عنوان العنصر
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? primaryColor : textColor,
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // شارة العدد (إن وجدت)
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(left: 6, right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor ?? primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize * 0.8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // بناء عنصر قائمة مخصص
  Widget _buildCustomMenuItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required double itemHeight,
    required double iconSize,
    required double fontSize,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: itemHeight,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // أيقونة العنصر
            Container(
              width: itemHeight * 0.7,
              height: itemHeight * 0.7,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: textColor.withOpacity(0.7),
                size: iconSize,
              ),
            ),
            
            // عنوان العنصر
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // سهم
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.chevron_right,
                color: textColor.withOpacity(0.5),
                size: iconSize * 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // بناء عنوان قسم
  Widget _buildSectionTitle(String title, double fontSize) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // بناء فاصل أفقي
  Widget _buildDivider(double padding) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: padding),
      child: Divider(
        color: textColor.withOpacity(0.1),
        thickness: 1,
      ),
    );
  }

  // بناء بطاقة البنق المحسنة
  Widget _buildPingCard(double screenWidth) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPingIndicator("فيسبوك", facebookPing, Icons.facebook),
              _buildPingIndicator("جوجل", googlePing, Icons.search),
              _buildPingIndicator("تيك توك", tiktokPing, Icons.music_video),
            ],
          ),
        ],
      ),
    );
  }

  // بناء مؤشر سرعة محسن
  Widget _buildPingIndicator(String name, int ping, IconData icon) {
    // تحديد حالة السرعة واللون
    String status;
    Color color;
    
    if (ping < 0) {
      status = "غير متصل";
      color = Colors.red;
    } else if (ping < 100) {
      status = "ممتاز";
      color = secondaryColor;
    } else if (ping < 200) {
      status = "جيد";
      color = accentColor;
    } else {
      status = "بطيء";
      color = Colors.red;
    }
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: textColor,
            size: 16,
          ),
        ),
        SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
          ),
        ),
        SizedBox(height: 3),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            ping >= 0 ? "$ping ms" : "--",
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: 3),
        Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // بناء زر تسجيل الخروج المحسن
  Widget _buildLogoutButton(double fontSize) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.3),
        border: Border(
          top: BorderSide(
            color: textColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: ElevatedButton.icon(
        onPressed: onLogout,
        icon: const Icon(Icons.logout, size: 16),
        label: Text(
          "تسجيل الخروج",
          style: TextStyle(
            fontSize: fontSize * 1.1,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withOpacity(0.8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}