import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workfingerprint/layout/login_screen/login_view.dart';

String _normalizeArabic(String text) {
  text = text.replaceAll(RegExp(r'[أإآ]'), 'ا');
  text = text.replaceAll(RegExp(r'[ى]'), 'ي');
  text = text.replaceAll(RegExp(r'[ة]'), 'ه');
  return text.trim().toLowerCase();
}

class EngineerFormView extends StatefulWidget {
  const EngineerFormView({super.key});

  @override
  State<EngineerFormView> createState() => _EngineerFormViewState();
}

class _EngineerFormViewState extends State<EngineerFormView> {
  final TextEditingController _hospitalController = TextEditingController();
  final TextEditingController _newLeadHospitalController = TextEditingController(); // الحقل الجديد
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientPhoneController = TextEditingController();

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  String? selectedVisitType;
  String? selectedDevice;
  String? selectedSalesOption;
  List<String> selectedMultiSales = [];
  String userName = "Engineer";
  String userDepartment = "صيانة";
  bool _isLoading = false;
  bool isNewLocation = false;

  List<String> allHospitals = [];
  bool _isHospitalsLoading = true;

  final List<String> visitTypes = ["صيانة", "صيانة دورية", "مبيعات", "تسليم او استلام اوراق", "استلام او ارسال شحن"];
  final List<String> devices = ["ABG Blood Gas", "Electrolyte", "SBA733 Plus", "CBC Tek2", "CBC Tek500", "CBC Tek8510"];
  final List<String> salesOptions = ["ترك عينات ","رابيد تيست", "سكر", "اجهزه", "كل ذلك"];
  final List<String> salesPromisingOptions = ["رابيد تيست", "سكر", "أجهزة ", "كل ذلك "];

  final List<String> collectionVisits = ["تحصيل", "تسليم او استلام اوراق", "تسليم محاليل"];
  final List<String> salesDeptVisits = ["مبيعات", "ترك عينات"];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _loadAllHospitals();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<String> _uploadImage(File file) async {
    String cloudName = "dzs7dknzl";
    String uploadPreset = "work_fing";

    var uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
    var request = http.MultipartRequest("POST", uri);
    request.fields['upload_preset'] = uploadPreset;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var responseString = String.fromCharCodes(responseData);
        var jsonRes = jsonDecode(responseString);
        return jsonRes['secure_url'];
      }
      return "error";
    } catch (e) {
      return "error";
    }
  }

  Future<void> _loadAllHospitals() async {
    try {
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

  _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          userName = doc['name'] ?? "Engineer";
          userDepartment = doc['department'] ?? "صيانة";
        });
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginView()), (route) => false);
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

    if (_hospitalController.text.trim().isEmpty || selectedVisitType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("برجاء إكمال البيانات الأساسية")));
      return;
    }

    bool isSalesVisit = selectedVisitType == "مبيعات";
    if (isSalesVisit) {
      if (_newLeadHospitalController.text.trim().isEmpty || _clientNameController.text.trim().isEmpty || _clientPhoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("في حالة المبيعات، اسم المكان والعميل ورقم التليفون إجباري")));
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      String imageUrl = "N/A";
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
      }

      Position position = await _getGeoLocation();
      String googleMapsLink = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      User? user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('visit_reports').add({
        'engineer_name': userName,
        'department': userDepartment,
        'hospital': isSalesVisit ? _newLeadHospitalController.text.trim() : _hospitalController.text.trim(),
        'visit_type': selectedVisitType,
        'device_type': selectedDevice ?? "N/A",
        'client_name': isSalesVisit ? _clientNameController.text.trim() : "غير مسجل",
        'client_phone': isSalesVisit ? _clientPhoneController.text.trim() : "غير مسجل",
        'multi_sales_selected': userDepartment == "صيانة" ? selectedMultiSales : (selectedSalesOption ?? "لا يوجد"),
        'notes': _noteController.text.trim().isEmpty ? "لا توجد" : _noteController.text.trim(),
        'google_map_link': googleMapsLink,
        'image_url': imageUrl,
        'is_new_location': isSalesVisit ? isNewLocation : false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (isSalesVisit && isNewLocation) {
        await FirebaseFirestore.instance.collection('new_leads_locations').add({
          'hospital_name': _newLeadHospitalController.text.trim(), // إرسال اسم المكان المكتوب يدوياً للمدير
          'client_name': _clientNameController.text.trim(),
          'client_phone': _clientPhoneController.text.trim(),
          'location_link': googleMapsLink,
          'added_by': userName,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

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
    _newLeadHospitalController.clear();
    _noteController.clear();
    _clientNameController.clear();
    _clientPhoneController.clear();
    setState(() {
      _imageFile = null;
      selectedVisitType = null;
      selectedDevice = null;
      selectedSalesOption = null;
      selectedMultiSales = [];
      isNewLocation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isMaintenance = userDepartment == "صيانة";
    bool isSalesDept = userDepartment == "مبيعات";
    bool isCollectionDept = userDepartment == "تحصيل";

    List<String> displayedHospitals = List.from(allHospitals);
    if (isMaintenance) displayedHospitals.addAll(["أخرى...", "شركة الشحن"]);

    List<String> currentVisitTypes = isMaintenance ? visitTypes : (isSalesDept ? salesDeptVisits : collectionVisits);
    bool isSalesVisit = selectedVisitType == "مبيعات";
    bool isOther = selectedVisitType == "تسليم او استلام اوراق" || selectedVisitType == "استلام او ارسال شحن";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade800,
        leading: IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () => _logout(context)),
        title: Text("Welcome ${isMaintenance ? 'ENG.' : ''} $userName", style: const TextStyle(color: Colors.white, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildLabel("اسم المستشفى / المعمل (الحالي) *"),
            _isHospitalsLoading
                ? const LinearProgressIndicator(color: Colors.blue)
                : DropdownSearch<String>(
              filterFn: (item, filter) => _normalizeArabic(item).contains(_normalizeArabic(filter)),
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
              items: displayedHospitals,
              onChanged: (val) => setState(() => _hospitalController.text = val ?? ""),
              selectedItem: _hospitalController.text.isEmpty ? null : _hospitalController.text,
              dropdownDecoratorProps: DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  prefixIcon: Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.blue.shade800),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            if (!isMaintenance || _hospitalController.text == "أخرى...") ...[
              const SizedBox(height: 10),
              _buildTextField(_hospitalController, Icons.edit_location_alt, "اكتب اسم المكان يدوياً"),
            ],

            const SizedBox(height: 15),
            _buildLabel("نوع الزيارة *"),
            _buildDropdown(currentVisitTypes, selectedVisitType, (val) {
              setState(() {
                selectedVisitType = val;
                selectedDevice = null;
                selectedSalesOption = null;
                isNewLocation = false;
              });
            }, "اختر نوع الزيارة"),

            // الحقول الإضافية في حالة المبيعات فقط
            if (isSalesVisit) ...[
              const SizedBox(height: 15),
              _buildLabel("اسم المكان  *"),
              _buildTextField(_newLeadHospitalController, Icons.location_city, " اسم المكان "),
              const SizedBox(height: 10),
              _buildLabel("بيانات العميل *"),
              _buildTextField(_clientNameController, Icons.person, "اسم العميل"),
              const SizedBox(height: 10),
              _buildTextField(_clientPhoneController, Icons.phone, "رقم تليفون", isPhone: true),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text("هذه أول زيارة مبيعات للمكان؟ ", textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: isNewLocation,
                activeColor: Colors.green,
                onChanged: (val) => setState(() => isNewLocation = val!),
              ),
            ],

            if (!isCollectionDept) ...[
              const SizedBox(height: 15),
              _buildLabel(isSalesVisit || isSalesDept ? "تصنيف المبيعات *" : "نوع الجهاز *"),
              _buildDropdown(
                  (isSalesVisit || isSalesDept) ? salesOptions : devices,
                  selectedDevice,
                      (val) => setState(() => selectedDevice = val),
                  isOther ? "مغلق لهذا النوع" : "اختر",
                  isDisabled: isOther
              ),
            ],

            if (isMaintenance) ...[
              const SizedBox(height: 15),
              _buildLabel("صورة عداد السيارة (اختياري)"),
              _buildImagePicker(),
            ],

            if (isSalesDept) ...[
              const SizedBox(height: 15),
              _buildLabel("مبيعات واعدة"),
              _buildMultiSelect(salesPromisingOptions),
            ] else if (isSalesVisit && isMaintenance) ...[
              const SizedBox(height: 15),
              _buildLabel("مبيعات واعدة "),
              _buildRadioSelect(salesPromisingOptions),
            ],

            const SizedBox(height: 15),
            _buildLabel("ملاحظات (اختياري)"),
            _buildTextField(_noteController, Icons.note_add, "اكتب ملاحظاتك...", maxLines: 3),

            const SizedBox(height: 30),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  // --- الميثودز المساعدة ---
  Widget _buildLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)));
  Widget _buildTextField(TextEditingController controller, IconData icon, String hint, {int maxLines = 1, bool isPhone = false}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textAlign: TextAlign.right,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: Colors.blue.shade800), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
  Widget _buildDropdown(List<String> items, String? value, Function(String?)? onChanged, String hint, {bool isDisabled = false}) {
    return DropdownButtonFormField<String>(
      value: value,
      items: isDisabled ? null : items.map((e) => DropdownMenuItem(value: e, child: Align(alignment: Alignment.centerRight, child: Text(e)))).toList(),
      onChanged: isDisabled ? null : onChanged,
      decoration: InputDecoration(filled: isDisabled, fillColor: isDisabled ? Colors.grey.shade200 : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), hintText: hint),
    );
  }
  Widget _buildImagePicker() {
    return InkWell(
      onTap: _pickImage,
      child: Container(
        width: double.infinity, height: 150,
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade800)),
        child: _imageFile == null
            ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 40), Text("اضغط لالتقاط صورة")])
            : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_imageFile!, fit: BoxFit.cover)),
      ),
    );
  }
  Widget _buildMultiSelect(List<String> options) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
      child: Column(children: options.map((opt) => CheckboxListTile(title: Text(opt, textAlign: TextAlign.right), value: selectedMultiSales.contains(opt), onChanged: (val) => setState(() => val! ? selectedMultiSales.add(opt) : selectedMultiSales.remove(opt)))).toList()),
    );
  }
  Widget _buildRadioSelect(List<String> options) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
      child: Column(children: options.map((opt) => RadioListTile<String>(title: Text(opt, textAlign: TextAlign.right), value: opt, groupValue: selectedSalesOption, onChanged: (val) => setState(() => selectedSalesOption = val))).toList()),
    );
  }
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity, height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _submitData,
        child: const Text("حفظ وإرسال التقرير", style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
    );
  }
}