import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart';
import 'package:workfingerprint/layout/login_screen/login_view.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});

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
        title: const Text("إضافة جهاز جديد", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: deviceController,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: "اسم  المستشفى",
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تمت إضافة الجهاز للقائمة بنجاح")));
              }
            },
            child: const Text("حفظ الجهاز", style: TextStyle(color: Colors.white)),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNewDevice(context),
        backgroundColor: const Color(0xFF0D47A1),
        icon: const Icon(Icons.important_devices, color: Colors.white),
        label: const Text("إضافة جهاز جديد", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("لا يوجد مهندسين"));

          var users = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              var userData = users[index].data() as Map<String, dynamic>;
              if (userData['role'] == 'admin') return const SizedBox.shrink();

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
class UserReportsPage extends StatelessWidget {
  final String userId;
  final String userName;
  const UserReportsPage({required this.userId, required this.userName, super.key});

  Future<void> _exportExcel(List<QueryDocumentSnapshot> docs, int filterDays) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Reports'];
      excel.delete('Sheet1');

      sheet.appendRow([
        TextCellValue('المهندس'),
        TextCellValue('المستشفى'),
        TextCellValue('نوع الزيارة'),
        TextCellValue('نوع الجهاز (صيانة)'),
        TextCellValue(' المبيعات'),
        TextCellValue('اسم العميل'),
        TextCellValue('رقم التليفون'),
        TextCellValue('مبيعات واعدة'),
        TextCellValue('الملاحظات'), // الملاحظات موجودة هنا
        TextCellValue('التاريخ والوقت'),
        TextCellValue('رابط الموقع')
      ]);

      DateTime now = DateTime.now();
      for (var doc in docs) {
        var data = doc.data() as Map<String, dynamic>;
        DateTime? ts = (data['timestamp'] as Timestamp?)?.toDate();
        if (filterDays > 0 && ts != null && now.difference(ts).inDays > filterDays) continue;

        // الحل لعدم ضرب الإكسيل: التأكد من نوع الداتا (List أو String)
        var rawMultiSales = data['multi_sales_selected'];
        String multiSales = "";
        if (rawMultiSales is List) {
          multiSales = rawMultiSales.join(' - ');
        } else {
          multiSales = rawMultiSales?.toString() ?? "---";
        }

        bool isSales = data['visit_type'] == "مبيعات";

        sheet.appendRow([
          TextCellValue(userName),
          TextCellValue(data['hospital'] ?? ""),
          TextCellValue(data['visit_type'] ?? ""),
          TextCellValue(!isSales ? (data['device_type'] ?? "") : "---"),
          TextCellValue(isSales ? (data['device_type'] ?? "") : "---"),
          TextCellValue(data['client_name'] ?? "---"),
          TextCellValue(data['client_phone'] ?? "---"),
          TextCellValue(multiSales),
          TextCellValue(data['notes'] ?? "لا يوجد"), // تصدير الملاحظات
          TextCellValue(ts != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format(ts) : ""),
          TextCellValue(data['google_map_link'] ?? "لا يوجد رابط"),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getTemporaryDirectory();
        final String filePath = "${directory.path}/Report_$userName.xlsx";
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles([XFile(filePath)], text: 'تقرير المهندس $userName');
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
        title: Text("ENG.$userName",style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        actions: [
          StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(userId).collection('visit_reports').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                return IconButton(
                    icon: const Icon(Icons.file_download, color: Colors.white),
                    onPressed: snapshot.hasData ? () => _showExportOptions(context, snapshot.data!.docs) : null
                );
              }
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).collection('visit_reports').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: WidgetStateProperty.all(const Color(0xFF0D47A1)),
                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                columns: const [
                  DataColumn(label: Text('نوع الزيارة')),
                  DataColumn(label: Text('المستشفى')),
                  DataColumn(label: Text('الجهاز (صيانة)')),
                  DataColumn(label: Text(' مبيعات')),
                  DataColumn(label: Text('بيانات العميل')),
                  DataColumn(label: Text('مبيعات واعدة')),
                  DataColumn(label: Text('الملاحظات')),
                  DataColumn(label: Text('التاريخ')),
                  DataColumn(label: Text('الموقع')),
                ],
                rows: docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  DateTime? date = (data['timestamp'] as Timestamp?)?.toDate();
                  String formattedDateTime = date != null ? DateFormat('dd/MM/yyyy - hh:mm a').format(date) : "---";

                  bool isSales = data['visit_type'] == "مبيعات";

                  // الحل السحري هنا: التأكد من نوع الحقل قبل العرض
                  var rawMultiSales = data['multi_sales_selected'];
                  String multiStr = "";
                  if (rawMultiSales is List) {
                    multiStr = rawMultiSales.join(', ');
                  } else {
                    multiStr = rawMultiSales?.toString() ?? "---";
                  }

                  return DataRow(cells: [
                    DataCell(Text(data['visit_type'] ?? "---")),
                    DataCell(Text(data['hospital'] ?? "---")),
                    DataCell(Text(!isSales ? (data['device_type'] ?? "---") : "---")),
                    DataCell(Text(isSales ? (data['device_type'] ?? "---") : "---")),
                    DataCell(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['client_name'] ?? "---", style: const TextStyle(fontSize: 12)),
                        Text(data['client_phone'] ?? "", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    )),
                    DataCell(Text(multiStr, style: const TextStyle(fontSize: 12))),
                    DataCell(SizedBox(width: 150, child: Text(data['notes'] ?? "لا يوجد", overflow: TextOverflow.visible))),
                    DataCell(Text(formattedDateTime)),
                    DataCell(IconButton(icon: const Icon(Icons.location_on, color: Colors.red), onPressed: () async {
                      if (data['google_map_link'] != null) await launchUrl(Uri.parse(data['google_map_link']));
                    })),
                  ]);
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}