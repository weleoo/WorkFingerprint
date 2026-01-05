import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart';
import 'package:workfingerprint/layout/login_screen/login_view.dart';

// --- الصفحة الأولى: لوحة تحكم الإدمن ---
class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  String _searchQuery = "";

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
            if (data['role'] == 'admin') return false;
            String name = (data['name'] ?? "").toString().toLowerCase();
            String phone = (data['phone'] ?? "").toString();
            return name.contains(_searchQuery.toLowerCase()) || phone.contains(_searchQuery);
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

// --- الصفحة الثانية: التقارير بتعديلات الترتيب والبحث بالفترة ---
class UserReportsPage extends StatefulWidget {
  final String userId;
  final String userName;
  const UserReportsPage({required this.userId, required this.userName, super.key});

  @override
  State<UserReportsPage> createState() => _UserReportsPageState();
}

class _UserReportsPageState extends State<UserReportsPage> {
  DateTimeRange? _selectedDateRange; // لتخزين الفترة من وإلى

  Future<void> _exportExcel(List<QueryDocumentSnapshot> docs, int filterDays, {DateTimeRange? customRange}) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Reports'];
      excel.delete('Sheet1');

      sheet.appendRow([
        TextCellValue('المهندس'), TextCellValue('نوع الزيارة'), TextCellValue('المستشفى'),
        TextCellValue('الجهاز'), TextCellValue('التاريخ والوقت'), TextCellValue('المبيعات'),
        TextCellValue('اسم العميل'), TextCellValue('رقم التليفون'), TextCellValue('مبيعات واعدة'),
        TextCellValue('الملاحظات'), TextCellValue('رابط الموقع')
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
          TextCellValue(widget.userName), TextCellValue(data['visit_type'] ?? ""), TextCellValue(data['hospital'] ?? ""),
          TextCellValue(!isSales ? (data['device_type'] ?? "") : "---"),
          TextCellValue(DateFormat('dd/MM/yyyy HH:mm:ss').format(ts)),
          TextCellValue(isSales ? (data['device_type'] ?? "") : "---"),
          TextCellValue(data['client_name'] ?? "---"), TextCellValue(data['client_phone'] ?? "---"),
          TextCellValue(multiSales), TextCellValue(data['notes'] ?? "لا يوجد"),
          TextCellValue(data['google_map_link'] ?? "لا يوجد رابط"),
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
            icon: const Icon(Icons.date_range, color: Colors.white), // شكل الكاليندر
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

                var docs = snapshot.data!.docs.where((doc) {
                  if (_selectedDateRange == null) return true;
                  DateTime? ts = (doc.data() as Map<String, dynamic>)['timestamp']?.toDate();
                  if (ts == null) return false;
                  // فحص إذا كان التاريخ يقع ضمن الفترة المختارة
                  return ts.isAfter(_selectedDateRange!.start.subtract(const Duration(seconds: 1))) &&
                      ts.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
                }).toList();

                if (docs.isEmpty) return const Center(child: Text("لا توجد بيانات لهذه الفترة"));

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                      child: DataTable(
                        columnSpacing: 20,
                        horizontalMargin: 10,
                        headingRowColor: WidgetStateProperty.all(const Color(0xFF0D47A1)),
                        headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        columns: const [
                          DataColumn(label: SizedBox(width: 90, child: Text('نوع الزيارة'))),
                          DataColumn(label: SizedBox(width: 180, child: Text('اسم المستشفى'))), // عرض أوسع
                          DataColumn(label: SizedBox(width: 120, child: Text('الجهاز'))),
                          DataColumn(label: SizedBox(width: 140, child: Text('التاريخ والوقت'))), // التاريخ بعد الجهاز
                          DataColumn(label: SizedBox(width: 90, child: Text('مبيعات'))),
                          DataColumn(label: SizedBox(width: 140, child: Text('بيانات العميل'))),
                          DataColumn(label: SizedBox(width: 110, child: Text('مبيعات واعدة'))),
                          DataColumn(label: SizedBox(width: 200, child: Text('الملاحظات'))),
                          DataColumn(label: Text('الموقع')),
                        ],
                        rows: docs.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          DateTime? date = (data['timestamp'] as Timestamp?)?.toDate();

                          String formattedDate = date != null ? DateFormat('dd/MM/yyyy').format(date) : "---";
                          String formattedTime = date != null ? DateFormat('hh:mm a').format(date) : "---";

                          bool isSales = data['visit_type'] == "مبيعات";
                          var rawMultiSales = data['multi_sales_selected'];
                          String multiStr = rawMultiSales is List ? rawMultiSales.join(', ') : (rawMultiSales?.toString() ?? "---");

                          return DataRow(cells: [
                            DataCell(SizedBox(width: 90, child: Text(data['visit_type'] ?? "---"))),
                            // المستشفى: بولد ولون مختلف وفي سطر لوحده (Block)
                            DataCell(SizedBox(width: 180, child: Text(
                              data['hospital'] ?? "---",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0), fontSize: 13),
                              softWrap: true,
                            ))),
                            DataCell(SizedBox(width: 120, child: Text(!isSales ? (data['device_type'] ?? "---") : "---"))),
                            // التاريخ والساعة: الساعة بولد ولون مختلف
                            DataCell(SizedBox(width: 140, child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(formattedDate, style: const TextStyle(fontSize: 11)),
                                Text(formattedTime, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                              ],
                            ))),
                            DataCell(SizedBox(width: 90, child: Text(isSales ? (data['device_type'] ?? "---") : "---"))),
                            DataCell(SizedBox(width: 140, child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['client_name'] ?? "---", style: const TextStyle(fontSize: 12)),
                                Text(data['client_phone'] ?? "", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ))),
                            DataCell(SizedBox(width: 110, child: Text(multiStr, style: const TextStyle(fontSize: 12)))),
                            DataCell(SizedBox(width: 200, child: Text(data['notes'] ?? "لا يوجد", softWrap: true))),
                            DataCell(IconButton(icon: const Icon(Icons.location_on, color: Colors.red), onPressed: () async {
                              if (data['google_map_link'] != null) await launchUrl(Uri.parse(data['google_map_link']));
                            })),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}