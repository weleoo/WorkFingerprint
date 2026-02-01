import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart' as excel_file;
import 'package:workfingerprint/layout/login_screen/login_view.dart';
String _normalizeArabic(String text) {
  text = text.replaceAll(RegExp(r'[أإآ]'), 'ا');
  text = text.replaceAll(RegExp(r'[ى]'), 'ي');
  text = text.replaceAll(RegExp(r'[ة]'), 'ه');
  return text.trim().toLowerCase();
}
class NewLocationsView extends StatelessWidget {
  const NewLocationsView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("الأماكن الجديدة المضافة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('new_leads_locations').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("لا توجد أماكن جديدة"));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              DateTime? ts = (data['timestamp'] as Timestamp?)?.toDate();
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  title: Text(data['hospital_name'] ?? "اسم المكان", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("العميل: ${data['client_name'] ?? '---'}"),
                      Text("الهاتف: ${data['client_phone'] ?? '---'}"),
                      Text("بواسطة: ${data['added_by'] ?? '---'}", style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                      if (ts != null) Text("التاريخ: ${DateFormat('dd/MM/yyyy').format(ts)}", style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.location_on, color: Colors.red, size: 30),
                    onPressed: () => launchUrl(Uri.parse(data['location_link'] ?? "")),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});
  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}
class _AdminDashboardViewState extends State<AdminDashboardView> {
  String _searchQuery = "";
  String _adminRole = ""; // لتخزين رتبة المدير الحالي
  @override
  void initState() {
    super.initState();
    _fetchAdminRole();
  }
  Future<void> _fetchAdminRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _adminRole = doc.data()?['role'] ?? "";
        });
      }
    }
  }
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
            (route) => false,
      );
    }
  }
  void _addNewDevice(BuildContext context) {
    TextEditingController deviceController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("إضافة مستشفى جديد", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: deviceController,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: "اسم المستشفى",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.add_to_photos_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(color: Colors.red))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              if (deviceController.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('hospitals').add({'name': deviceController.text.trim()});
                if (context.mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تمت إضافة المستشفى بنجاح")));
              }
            },
            child: const Text("حفظ", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () => _logout(context)),
        title: const Text("Cairo Diagnostic", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.fiber_new, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NewLocationsView())),
          ),
          IconButton(
            icon: const Icon(Icons.manage_search, size: 30, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GlobalSearchPage(adminRole: _adminRole))),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: TextField(
              textAlign: TextAlign.right,
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
              decoration: InputDecoration(
                hintText: "بحث باسم المهندس أو رقم التليفون",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0D47A1)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),

      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNewDevice(context),
        backgroundColor: const Color(0xFF0D47A1),
        icon: const Icon(Icons.important_devices, color: Colors.white),
        label: const Text("إضافة مستشفى جديد", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("لا يوجد مهندسين"));
          var users = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['role'].toString().contains('admin')) return false;
            bool isVisible = false;
            String userDept = data['department'] ?? "";
            if (_adminRole == "super_admin") {
              isVisible = true;
            } else if (_adminRole == "admin_maintenance" && userDept == "صيانة") {
              isVisible = true;
            } else if (_adminRole == "admin_sales" && userDept == "مبيعات") {
              isVisible = true;
            } else if (_adminRole == "admin_collection" && userDept == "تحصيل") {
              isVisible = true;
            }
            String name = (data['name'] ?? "").toString().toLowerCase();
            String phone = (data['phone'] ?? "").toString();
            bool matchesSearch = name.contains(_searchQuery.toLowerCase()) || phone.contains(_searchQuery);
            return isVisible && matchesSearch;
          }).toList();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              var userData = users[index].data() as Map<String, dynamic>;
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.blue.shade100, child: const Icon(Icons.person, color: Color(0xFF0D47A1))),
                  title: Text("ENG. ${userData['name'] ?? 'Engineer'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("📞 ${userData['phone'] ?? 'بدون رقم'}", style: const TextStyle(color: Colors.blueGrey)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF0D47A1)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (context) => UserReportsPage(userId: users[index].id, userName: userData['name'] ?? "")
                  )),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
class GlobalSearchPage extends StatefulWidget {
  final String adminRole;
  const GlobalSearchPage({required this.adminRole, super.key});
  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}
class _GlobalSearchPageState extends State<GlobalSearchPage> {
  String _query = "";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("البحث الشامل", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo.shade900,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              autofocus: true,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: "ابحث باسم المستشفى أو موديل الجهاز...",
                fillColor: Colors.white,
                filled: true,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
        ),
      ),
      body: _query.isEmpty
          ? const Center(child: Text("أدخل المستشفي المراد البحث عنها في كافة التقارير"))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collectionGroup('visit_reports').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData) return const Center(child: Text("لا توجد بيانات"));
          var results = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            bool deptMatch = false;
            String visitType = data['visit_type'] ?? "";
            if (widget.adminRole == "super_admin") deptMatch = true;
            else if (widget.adminRole == "admin_maintenance" && visitType == "صيانة") deptMatch = true;
            else if (widget.adminRole == "admin_sales" && visitType == "مبيعات") deptMatch = true;
            else if (widget.adminRole == "admin_collection" && visitType == "تحصيل") deptMatch = true;
            String hospitalNormalized = _normalizeArabic(data['hospital'] ?? "");
            String deviceNormalized = _normalizeArabic(data['device_type'] ?? "");
            String queryNormalized = _normalizeArabic(_query);
            return (hospitalNormalized.contains(queryNormalized) || deviceNormalized.contains(queryNormalized)) && deptMatch;
          }).toList();
          if (results.isEmpty) return const Center(child: Text("لا توجد نتائج مطابقة لبحثك في قسمك"));
          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              var data = results[index].data() as Map<String, dynamic>;
              DateTime? ts = (data['timestamp'] as Timestamp?)?.toDate();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 3,
                child: ListTile(
                  title: Text(data['hospital'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("الجهاز: ${data['device_type'] ?? '---'}", style: const TextStyle(color: Colors.black87)),
                      Text("التاريخ: ${ts != null ? DateFormat('dd/MM/yyyy hh:mm a').format(ts) : '---'}"),
                      const Divider(),
                      Row(
                        children: [
                          const Icon(Icons.person_pin, size: 16, color: Colors.red),
                          const SizedBox(width: 5),
                          Text("المهندس: ${data['engineer_name'] ?? 'غير مسجل'}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
class UserReportsPage extends StatefulWidget {
  final String userId;
  final String userName;
  const UserReportsPage({required this.userId, required this.userName, super.key});
  @override
  State<UserReportsPage> createState() => _UserReportsPageState();
}
class _UserReportsPageState extends State<UserReportsPage> {
  DateTimeRange? _selectedDateRange;
  String _formatDuration(int totalMinutes) {
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;
    return " س$hours د $minutes ";
  }
  void _viewImage(String? url) {
    if (url == null || url.isEmpty || url == "N/A") return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(url, fit: BoxFit.contain),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إغلاق")),
          ],
        ),
      ),
    );
  }
  Future<void> _exportExcel(List<QueryDocumentSnapshot> docs, int filterDays, {DateTimeRange? customRange}) async {
    try {
      var excel = excel_file.Excel.createExcel();
      excel_file.Sheet sheet = excel['Reports'];
      excel.delete('Sheet1');
      sheet.appendRow([
        excel_file.TextCellValue('المهندس'), excel_file.TextCellValue('نوع الزيارة'), excel_file.TextCellValue('المستشفى'),
        excel_file.TextCellValue('الجهاز'), excel_file.TextCellValue('التاريخ والوقت'), excel_file.TextCellValue('المبيعات'),
        excel_file.TextCellValue('اسم العميل'), excel_file.TextCellValue('رقم التليفون'), excel_file.TextCellValue('مبيعات واعدة'),
        excel_file.TextCellValue('الملاحظات'), excel_file.TextCellValue('رابط الموقع')
      ]);
      DateTime now = DateTime.now();
      for (var doc in docs) {
        var data = doc.data() as Map<String, dynamic>;
        DateTime? ts = (data['timestamp'] as Timestamp?)?.toDate();
        if (ts == null) continue;
        if (customRange != null) {
          if (ts.isBefore(customRange.start) || ts.isAfter(customRange.end.add(const Duration(days: 1)))) continue;
        } else if (filterDays > 0 && now.difference(ts).inDays > filterDays) {
          continue;
        }
        var rawMultiSales = data['multi_sales_selected'];
        String multiSales = rawMultiSales is List ? rawMultiSales.join(' - ') : (rawMultiSales?.toString() ?? "---");
        bool isSales = data['visit_type'] == "مبيعات";

        sheet.appendRow([
          excel_file.TextCellValue(widget.userName), excel_file.TextCellValue(data['visit_type'] ?? ""), excel_file.TextCellValue(data['hospital'] ?? ""),
          excel_file.TextCellValue(!isSales ? (data['device_type'] ?? "") : "---"),
          excel_file.TextCellValue(DateFormat('dd/MM/yyyy HH:mm:ss').format(ts)),
          excel_file.TextCellValue(isSales ? (data['device_type'] ?? "") : "---"),
          excel_file.TextCellValue(data['client_name'] ?? "---"), excel_file.TextCellValue(data['client_phone'] ?? "---"),
          excel_file.TextCellValue(multiSales), excel_file.TextCellValue(data['notes'] ?? "لا يوجد"),
          excel_file.TextCellValue(data['google_map_link'] ?? "لا يوجد رابط"),
        ]);
      }
      var fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getTemporaryDirectory();
        final String filePath = "${directory.path}/Report_${widget.userName}.xlsx";
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles([XFile(filePath)], text: 'تقرير المهندس ${widget.userName}');
      }
    } catch (e) {
      debugPrint("Export Error: $e");
    }
  }
  void _showExportOptions(BuildContext context, List<QueryDocumentSnapshot> docs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text("تصدير ملف Excel", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ListTile(leading: const Icon(Icons.all_inclusive, color: Colors.blue), title: const Text("تصدير الكل"), onTap: () { Navigator.pop(context); _exportExcel(docs, 0); }),
          ListTile(leading: const Icon(Icons.date_range, color: Colors.purple), title: const Text("تحديد تاريخ مخصص"),
              onTap: () async {
                Navigator.pop(context);
                DateTimeRange? range = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now());
                if (range != null) _exportExcel(docs, 0, customRange: range);
              }
          ),
          ListTile(leading: const Icon(Icons.calendar_view_day, color: Colors.green), title: const Text("آخر 10 أيام"), onTap: () { Navigator.pop(context); _exportExcel(docs, 10); }),
          ListTile(leading: const Icon(Icons.calendar_month, color: Colors.orange), title: const Text("آخر شهر"), onTap: () { Navigator.pop(context); _exportExcel(docs, 30); }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ENG.${widget.userName}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            onPressed: () async {
              DateTimeRange? picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                helpText: "اختر الفترة الزمنية",
                saveText: "تطبيق",
              );
              if (picked != null) setState(() => _selectedDateRange = picked);
            },
          ),
          StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('visit_reports').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                return IconButton(
                    icon: const Icon(Icons.file_download, color: Colors.white),
                    onPressed: snapshot.hasData ? () => _showExportOptions(context, snapshot.data!.docs) : null
                );
              }
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedDateRange != null)
            Container(
              color: Colors.blue.shade50,
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.filter_alt, size: 16, color: Color(0xFF0D47A1)),
                  const SizedBox(width: 8),
                  Text(
                    "من: ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)}  إلى: ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.red), onPressed: () => setState(() => _selectedDateRange = null))
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('visit_reports').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var rawDocs = snapshot.data!.docs;
                var filteredDocs = rawDocs.where((doc) {
                  if (_selectedDateRange == null) return true;
                  DateTime? ts = (doc.data() as Map<String, dynamic>)['timestamp']?.toDate();
                  if (ts == null) return false;
                  return ts.isAfter(_selectedDateRange!.start.subtract(const Duration(seconds: 1))) &&
                      ts.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
                }).toList();
                if (filteredDocs.isEmpty) return const Center(child: Text("لا توجد بيانات لهذه الفترة"));
                Map<String, List<QueryDocumentSnapshot>> groupedByDay = {};
                for (var doc in filteredDocs) {
                  DateTime? ts = (doc.data() as Map<String, dynamic>)['timestamp']?.toDate();
                  if (ts != null) {
                    String dayKey = DateFormat('yyyy-MM-dd').format(ts);
                    groupedByDay.putIfAbsent(dayKey, () => []).add(doc);
                  }
                }
                int totalPeriodMinutes = 0;
                int actualWorkingDays = 0;
                Map<String, String> dayCalculations = {};
                groupedByDay.forEach((day, docs) {
                  if (docs.length >= 2) {
                    docs.sort((a, b) => ((a.data() as Map)['timestamp'] as Timestamp).compareTo((b.data() as Map)['timestamp'] as Timestamp));
                    DateTime first = (docs.first.data() as Map<String, dynamic>)['timestamp'].toDate();
                    DateTime last = (docs.last.data() as Map<String, dynamic>)['timestamp'].toDate();
                    int diff = last.difference(first).inMinutes;
                    totalPeriodMinutes += diff;
                    actualWorkingDays++;
                    dayCalculations[docs.last.id] = _formatDuration(diff);
                  }
                });
                String avgWorkHours = actualWorkingDays > 0
                    ? _formatDuration(totalPeriodMinutes ~/ actualWorkingDays)
                    : "---";
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2))],
                          border: const Border(right: BorderSide(color: Color(0xFF0D47A1), width: 6))
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("متوسط العمل (لكل يوم عمل فعلي):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(avgWorkHours, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.grey.shade300),
                              child: DataTable(
                                columnSpacing: 25,
                                horizontalMargin: 15,
                                dataRowMaxHeight: 85,
                                dataRowMinHeight: 65,
                                headingRowHeight: 55,
                                headingRowColor: WidgetStateProperty.all(const Color(0xFF0D47A1)),
                                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                columns: const [
                                  DataColumn(label: Text('نوع الزيارة')),
                                  DataColumn(label: Text('اسم المستشفى')),
                                  DataColumn(label: Text('الجهاز')),
                                  DataColumn(label: Text('التاريخ والوقت')),
                                  DataColumn(label: Text('الصور')),
                                  DataColumn(label: Text('ساعات العمل')),
                                  DataColumn(label: Text('مبيعات')),
                                  DataColumn(label: Text('بيانات العميل')),
                                  DataColumn(label: Text('مبيعات واعدة')),
                                  DataColumn(label: Text('الملاحظات')),
                                  DataColumn(label: Text('الموقع')),
                                ],
                                rows: filteredDocs.map((doc) {
                                  var data = doc.data() as Map<String, dynamic>;
                                  DateTime? date = (data['timestamp'] as Timestamp?)?.toDate();
                                  String formattedDate = date != null ? DateFormat('dd/MM/yyyy').format(date) : "---";
                                  String formattedTime = date != null ? DateFormat('hh:mm a').format(date) : "---";
                                  bool isSales = data['visit_type'] == "مبيعات";
                                  var rawMultiSales = data['multi_sales_selected'];
                                  String multiStr = rawMultiSales is List ? rawMultiSales.join(', ') : (rawMultiSales?.toString() ?? "---");
                                  return DataRow(cells: [
                                    DataCell(Text(data['visit_type'] ?? "---", style: const TextStyle(fontWeight: FontWeight.w500))),
                                    DataCell(SizedBox(
                                      width: 180,
                                      child: Text(data['hospital'] ?? "---",
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0), fontSize: 14),
                                        softWrap: true,
                                      ),
                                    )),
                                    DataCell(Text(!isSales ? (data['device_type'] ?? "---") : "---")),
                                    DataCell(Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          const SizedBox(height: 4),
                                          Text(formattedTime, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                        ],
                                      ),
                                    )),
                                    DataCell(
                                        data['image_url'] != null && data['image_url'] != "N/A"
                                            ? IconButton(
                                          icon: const Icon(Icons.image, color: Colors.blue),
                                          onPressed: () => _viewImage(data['image_url']),
                                        )
                                            : const Text("---")
                                    ),
                                    DataCell(Center(child: Text(dayCalculations[doc.id] ?? "---", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)))),
                                    DataCell(Text(isSales ? (data['device_type'] ?? "---") : "---")),
                                    DataCell(Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(data['client_name'] ?? "---", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                        Text(data['client_phone'] ?? "", style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                                      ],
                                    )),
                                    DataCell(SizedBox(width: 110, child: Text(multiStr, style: const TextStyle(fontSize: 12), softWrap: true))),
                                    DataCell(SizedBox(width: 220, child: Text(data['notes'] ?? "لا يوجد", style: const TextStyle(fontSize: 12, height: 1.3), softWrap: true))),
                                    DataCell(IconButton(icon: const Icon(Icons.location_on, color: Colors.red, size: 28), onPressed: () async {
                                      if (data['google_map_link'] != null) await launchUrl(Uri.parse(data['google_map_link']));
                                    })),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}