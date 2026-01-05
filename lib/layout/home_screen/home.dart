import 'package:dropdown_search/dropdown_search.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workfingerprint/layout/login_screen/login_view.dart';

class EngineerFormView extends StatefulWidget {
  const EngineerFormView({super.key});

  @override
  State<EngineerFormView> createState() => _EngineerFormViewState();
}

class _EngineerFormViewState extends State<EngineerFormView> {
  final TextEditingController _hospitalController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientPhoneController = TextEditingController();

  String? selectedVisitType;
  String? selectedDevice;
  String? selectedSalesOption;
  String userName = "Engineer";
  bool _isLoading = false;

  List<String> allHospitals = [];
  bool _isHospitalsLoading = true;

  final List<String> visitTypes = ["صيانة", "صيانة دورية", "مبيعات", "تسليم او استلام اوراق", "استلام او ارسال شحن"];
  final List<String> devices = ["ABG Blood Gas", "Electrolyte", "SBA733 Plus", "CBC Tek2", "CBC Tek500", "CBC Tek8510"];
  final List<String> salesOptions = ["ترك عينات ","رابيد تيست", "سكر", "اجهزه", "كل ذلك"];
  final List<String> salesPromisingOptions = ["رابيد تيست", "سكر", "أجهزة ", "كل ذلك "];

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _loadAllHospitals();
  }

  Future<void> _loadAllHospitals() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      var snapshot = await FirebaseFirestore.instance.collection('hospitals').get();
      if (mounted) {
        setState(() {
          allHospitals = snapshot.docs.map((doc) => doc['name'].toString()).toList();
          _isHospitalsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isHospitalsLoading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginView()), (route) => false);
  }

  _fetchUserName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) setState(() => userName = doc['name'] ?? "Engineer");
    }
  }

  Future<Position> _getGeoLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _submitData() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا يوجد اتصال بالإنترنت")));
      return;
    }

    if (_hospitalController.text.isEmpty || selectedVisitType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("برجاء إكمال البيانات الأساسية")));
      return;
    }

    bool isGeneralVisit = selectedVisitType == "تسليم او استلام اوراق" ||
        selectedVisitType == "استلام او ارسال شحن";

    if (!isGeneralVisit && selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("برجاء اختيار نوع الجهاز أو تصنيف المبيعات")));
      return;
    }

    if (selectedVisitType == "مبيعات" && (_clientNameController.text.isEmpty || _clientPhoneController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("برجاء إدخال اسم العميل ورقم تليفونه")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      Position position = await _getGeoLocation();
      String googleMapsLink = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      User? user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('visit_reports').add({
        'engineer_name': userName.toString(),
        'hospital': _hospitalController.text.trim(),
        'visit_type': selectedVisitType.toString(),
        'device_type': isGeneralVisit ? selectedVisitType.toString() : (selectedDevice?.toString() ?? "N/A"),
        'client_name': _clientNameController.text.trim(),
        'client_phone': _clientPhoneController.text.trim(),
        'multi_sales_selected': selectedSalesOption?.toString() ?? "لا يوجد",
        'notes': _noteController.text.trim().isEmpty ? "لا توجد" : _noteController.text.trim(),
        'google_map_link': googleMapsLink,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الحفظ بنجاح!")));
      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _hospitalController.clear();
    _noteController.clear();
    _clientNameController.clear();
    _clientPhoneController.clear();
    setState(() {
      selectedVisitType = null;
      selectedDevice = null;
      selectedSalesOption = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isSales = selectedVisitType == "مبيعات";
    bool isOther = selectedVisitType == "تسليم او استلام اوراق" ||
        selectedVisitType == "استلام او ارسال شحن";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade800,
        leading: IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () => _logout(context)),
        title: Text("Welcome ENG. $userName", style: const TextStyle(color: Colors.white, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildLabel("اسم المستشفى / المعمل"),
            _isHospitalsLoading
                ? const LinearProgressIndicator(color: Colors.blue)
                : DropdownSearch<String>(
              // --- تفعيل السيرش هنا ---
              popupProps: PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: "ابحث عن مستشفى...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                itemBuilder: (context, item, isSelected) => Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(item, textAlign: TextAlign.right),
                ),
              ),
              // -----------------------
              items: allHospitals,
              onChanged: (val) => setState(() => _hospitalController.text = val ?? ""),
              selectedItem: _hospitalController.text.isEmpty ? null : _hospitalController.text,
              dropdownDecoratorProps: DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  prefixIcon: Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.blue.shade800),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 15),
            _buildLabel("نوع الزيارة"),
            _buildDropdown(visitTypes, selectedVisitType, (val) {
              setState(() {
                selectedVisitType = val;
                selectedDevice = null;
                selectedSalesOption = null;
              });
            }, "اختر نوع الزيارة", isDisabled: false),
            const SizedBox(height: 15),

            _buildLabel(isSales ? "تصنيف المبيعات" : "نوع الجهاز"),
            _buildDropdown(
                isSales ? salesOptions : devices,
                selectedDevice,
                    (val) => setState(() => selectedDevice = val),
                isOther ? "مغلق لهذا النوع" : "اختر",
                isDisabled: isOther
            ),

            if (isSales) ...[
              const SizedBox(height: 15),
              _buildLabel("بيانات العميل"),
              _buildTextField(_clientNameController, Icons.person, "اسم العميل"),
              const SizedBox(height: 10),
              _buildTextField(_clientPhoneController, Icons.phone, "رقم التليفون"),
              const SizedBox(height: 15),
              _buildLabel("مبيعات واعدة "),
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: salesPromisingOptions.map((String option) {
                    return RadioListTile<String>(
                      title: Text(option, textAlign: TextAlign.right),
                      value: option,
                      groupValue: selectedSalesOption,
                      activeColor: Colors.blue.shade800,
                      onChanged: (String? value) => setState(() => selectedSalesOption = value),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 15),
            _buildLabel("ملاحظات (اختياري)"),
            _buildTextField(_noteController, Icons.note_add, "اكتب ملاحظاتك...", maxLines: 3),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _submitData,
                child: const Text("حفظ وإرسال التقرير", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)));

  Widget _buildTextField(TextEditingController controller, IconData icon, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.blue.shade800),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String? value, Function(String?)? onChanged, String hint, {bool isDisabled = false}) {
    return DropdownButtonFormField<String>(
      value: value,
      items: isDisabled ? null : items.map((e) => DropdownMenuItem(value: e, child: Align(alignment: Alignment.centerRight, child: Text(e)))).toList(),
      onChanged: isDisabled ? null : onChanged,
      decoration: InputDecoration(
        filled: isDisabled,
        fillColor: isDisabled ? Colors.grey.shade200 : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        hintText: hint,
        hintStyle: TextStyle(color: isDisabled ? Colors.grey : Colors.black54),
      ),
    );
  }
}