import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_screen.dart';
import 'config.dart';

class AddDataScreen extends StatefulWidget {
  final double? latitude;
  final double? longitude;

  const AddDataScreen({
    super.key,
    this.latitude,
    this.longitude,
  });

  @override
  State<AddDataScreen> createState() => _AddDataScreenState();
}

class _AddDataScreenState extends State<AddDataScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;

  // State สำหรับเปิด/ปิดที่อยู่ที่ 2
  bool _showSecondAddress = false;

  final DateFormat _fmtDisplay = DateFormat('dd/MM/yyyy');
  final DateFormat _fmtApi = DateFormat('yyyy-MM-dd');

  // Controllers (ข้อมูลส่วนตัว)
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _diseaseController = TextEditingController();
  final _startDateController = TextEditingController();
  final _sickDateController = TextEditingController();
  final _healingDateController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  
  // พิกัด 1
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  
  final _dangerRangeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dangerLevelController = TextEditingController();

  // Controllers (ที่อยู่ 1)
  final _addrHouseNo = TextEditingController();
  final _addrMoo = TextEditingController();
  final _addrVillage = TextEditingController();
  final _addrSoi = TextEditingController();
  final _addrRoad = TextEditingController();
  final _addrSubdistrict = TextEditingController();
  final _addrDistrict = TextEditingController();
  final _addrProvince = TextEditingController();
  final _addrPostcode = TextEditingController();
  final _addrLandmark = TextEditingController();

  // Controllers (ที่อยู่ 2 - เพิ่มใหม่)
  final _addrHouseNo2 = TextEditingController();
  final _addrMoo2 = TextEditingController();
  final _addrVillage2 = TextEditingController();
  final _addrSoi2 = TextEditingController();
  final _addrRoad2 = TextEditingController();
  final _addrSubdistrict2 = TextEditingController();
  final _addrDistrict2 = TextEditingController();
  final _addrProvince2 = TextEditingController();
  final _addrPostcode2 = TextEditingController();
  final _addrLandmark2 = TextEditingController();

  // ✅ เพิ่ม: พิกัด 2
  final _latitudeController2 = TextEditingController();
  final _longitudeController2 = TextEditingController();

  String? _selectedDangerLevel;
  final List<String> _dangerLevelOptions = ['ระยะแรก', 'ระยะที่สอง', 'เสียชีวิต'];

  List<String> _diseaseOptions = [];
  bool _loadingDiseases = true;

  static const _primary = Color(0xFF0E47A1);

  // ... (ส่วน Overlay/SnackBar เหมือนเดิม) ...
  OverlayEntry? _bannerEntry;
  Timer? _bannerTimer;

  void _hideBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    _bannerEntry?.remove();
    _bannerEntry = null;
  }

  void _showFancySnack(String message, {bool success = false}) {
    _hideBanner();
    final bg = success ? _primary : Colors.red.shade600;
    final icon = success ? Icons.check_circle : Icons.error_outline;
    const double bottomOffset = 96;

    _bannerEntry = OverlayEntry(
      builder: (context) {
        final bottomInset = MediaQuery.of(context).padding.bottom;
        return Positioned(
          left: 16,
          right: 16,
          bottom: bottomInset + bottomOffset,
          child: IgnorePointer(
            ignoring: true,
            child: Material(
              color: Colors.transparent,
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_bannerEntry!);
    _bannerTimer = Timer(const Duration(seconds: 3), _hideBanner);
  }

  @override
  void initState() {
    super.initState();
    _selectedDangerLevel = _dangerLevelOptions[0];
    _dangerLevelController.text = _selectedDangerLevel!;

    if (widget.latitude != null) _latitudeController.text = widget.latitude!.toStringAsFixed(6);
    if (widget.longitude != null) _longitudeController.text = widget.longitude!.toStringAsFixed(6);

    _fetchDiseases();
  }

  @override
  void dispose() {
    _hideBanner();
    // Dispose Controllers 1
    _nameController.dispose(); _diseaseController.dispose(); _startDateController.dispose();
    _sickDateController.dispose(); _healingDateController.dispose(); _phoneNumberController.dispose();
    _latitudeController.dispose(); _longitudeController.dispose(); _dangerRangeController.dispose();
    _descriptionController.dispose(); _dangerLevelController.dispose();
    _addrHouseNo.dispose(); _addrMoo.dispose(); _addrVillage.dispose(); _addrSoi.dispose();
    _addrRoad.dispose(); _addrSubdistrict.dispose(); _addrDistrict.dispose(); _addrProvince.dispose();
    _addrPostcode.dispose(); _addrLandmark.dispose();

    // Dispose Controllers 2
    _addrHouseNo2.dispose(); _addrMoo2.dispose(); _addrVillage2.dispose(); _addrSoi2.dispose();
    _addrRoad2.dispose(); _addrSubdistrict2.dispose(); _addrDistrict2.dispose(); _addrProvince2.dispose();
    _addrPostcode2.dispose(); _addrLandmark2.dispose();
    // ✅ Dispose พิกัด 2
    _latitudeController2.dispose(); _longitudeController2.dispose();
    
    super.dispose();
  }

  // ... (ส่วน Theme, FetchDisease, ShowPicker, Helper Date, SelectDate เหมือนเดิม) ...
  Theme _popupTheme(BuildContext context, Widget child) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: const ColorScheme.light(primary: _primary, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black87),
        dialogTheme: DialogThemeData(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), titleTextStyle: const TextStyle(color: _primary, fontSize: 20, fontWeight: FontWeight.w700)),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: _primary)),
      ),
      child: child,
    );
  }

  Future<void> _fetchDiseases() async {
    setState(() => _loadingDiseases = true);
    try {
      final res = await http.get(ApiConfig.u('add_data.php', {'mode': 'diseases'}));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final setNames = <String>{};
        if (decoded is List) {
          for (final item in decoded) {
            final v = item is String ? item.trim() : (item is Map ? (item['name'] ?? item['disease'] ?? item['epidemic'] ?? item['title'])?.toString().trim() : null);
            if (v != null && v.isNotEmpty) setNames.add(v);
          }
        }
        if (!mounted) return;
        setState(() { _diseaseOptions = setNames.toList()..sort(); _loadingDiseases = false; });
      } else {
        if (!mounted) return;
        setState(() { _loadingDiseases = false; _diseaseOptions = []; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingDiseases = false; _diseaseOptions = []; });
    }
  }

  Future<String?> _showDiseasePickerWithSearch() async {
    String query = '';
    List<String> filtered = List.of(_diseaseOptions);
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _popupTheme(
          dialogContext,
          StatefulBuilder(
            builder: (context, setStateSB) {
              return AlertDialog(
                title: const Text('เลือก ชื่อโรค'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(hintText: 'พิมพ์เพื่อค้นหา...', prefixIcon: const Icon(Icons.search, color: _primary), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                        onChanged: (q) { query = q; final lower = q.toLowerCase(); filtered = _diseaseOptions.where((e) => e.toLowerCase().contains(lower)).toList(); setStateSB(() {}); },
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: filtered.isEmpty ? const Center(child: Text('ไม่พบรายการ')) : ListView.separated(shrinkWrap: true, itemCount: filtered.length, separatorBuilder: (_, _) => const Divider(height: 1), itemBuilder: (context, index) { final name = filtered[index]; return ListTile(title: Text(name, style: const TextStyle(fontSize: 18)), onTap: () => Navigator.pop(dialogContext, name)); }),
                      ),
                    ],
                  ),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ยกเลิก'))],
              );
            },
          ),
        );
      },
    );
  }

  String _toApiDate(String input) {
    final s = input.trim();
    if (s.isEmpty) return s;
    DateTime? dt;
    try { dt = _fmtDisplay.parseStrict(s); } catch (_) {}
    if (dt == null) { try { dt = _fmtApi.parseStrict(s); } catch (_) {} }
    return dt != null ? _fmtApi.format(dt) : s;
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101), builder: (ctx, child) => _popupTheme(ctx, child!));
    if (picked != null) {
      controller.text = _fmtDisplay.format(picked);
      if (_submitted) _formKey.currentState?.validate();
    }
  }

  // ... (Validators เหมือนเดิม) ...
  String? _requiredText(String? v, String label) => (v == null || v.trim().isEmpty) ? 'กรุณากรอก$label' : null;
  String? _requiredLat(String? v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอก' : (double.tryParse(v) == null ? 'ผิดรูปแบบ' : null);
  String? _requiredLng(String? v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอก' : (double.tryParse(v) == null ? 'ผิดรูปแบบ' : null);
  String? _phoneValidator(String? v) { if (v == null || v.trim().isEmpty) return 'กรุณากรอกเบอร์'; return v.replaceAll(RegExp(r'\D'), '').length < 9 ? 'เบอร์ไม่ถูกต้อง' : null; }
  String? _postcodeValidator(String? v) { if (v == null || v.trim().isEmpty) return 'กรุณากรอกรหัส'; return v.replaceAll(RegExp(r'\D'), '').length != 5 ? 'ครบ 5 หลัก' : null; }

  // ===== Helper สร้าง Full Address String =====
  String _buildFullAddress(TextEditingController house, TextEditingController moo, TextEditingController village, TextEditingController soi, TextEditingController road, TextEditingController sub, TextEditingController dist, TextEditingController prov, TextEditingController post) {
    return [
      if (house.text.trim().isNotEmpty) 'บ้านเลขที่ ${house.text.trim()}',
      if (moo.text.trim().isNotEmpty) 'หมู่ ${moo.text.trim()}',
      if (village.text.trim().isNotEmpty) 'หมู่บ้าน ${village.text.trim()}',
      if (soi.text.trim().isNotEmpty) 'ซอย ${soi.text.trim()}',
      if (road.text.trim().isNotEmpty) 'ถนน ${road.text.trim()}',
      if (sub.text.trim().isNotEmpty) 'ต.${sub.text.trim()}',
      if (dist.text.trim().isNotEmpty) 'อ.${dist.text.trim()}',
      if (prov.text.trim().isNotEmpty) 'จ.${prov.text.trim()}',
      if (post.text.trim().isNotEmpty) post.text.trim(),
    ].join(' ');
  }

  // ===== Save Function (Modified for 2 Addresses + 2 Coords) =====
  Future<void> _validateAndSave() async {
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showFancySnack('กรุณากรอกข้อมูลที่จำเป็นให้ครบ');
      return;
    }

    final url = ApiConfig.u('/add_data.php');

    // ข้อมูลส่วนตัว (ใช้ร่วมกันทั้ง 2 ที่อยู่)
    final personalData = {
      'pat_name': _nameController.text,
      'pat_surname': _surnameController.text,
      'pat_epidemic': _diseaseController.text.trim(),
      'pat_infection_date': _toApiDate(_startDateController.text),
      'pat_sick_date': _toApiDate(_sickDateController.text),
      'pat_recovery_date': _toApiDate(_healingDateController.text),
      'pat_phone': _phoneNumberController.text,
      'pat_danger_level': _selectedDangerLevel ?? 'ไม่ได้เลือก',
      'pat_danger_range': double.tryParse(_dangerRangeController.text) ?? 0.0,
      'pat_description': _descriptionController.text,
    };

    // --- บันทึกที่อยู่ 1 (ใช้พิกัดชุดที่ 1) ---
    final addr1Data = {
      ...personalData,
      // ✅ พิกัด 1
      'pat_latitude': double.tryParse(_latitudeController.text) ?? 0.0,
      'pat_longitude': double.tryParse(_longitudeController.text) ?? 0.0,
      // ที่อยู่ 1
      'pat_address_house_no': _addrHouseNo.text,
      'pat_address_moo': _addrMoo.text,
      'pat_address_village': _addrVillage.text,
      'pat_address_soi': _addrSoi.text,
      'pat_address_road': _addrRoad.text,
      'pat_address_subdistrict': _addrSubdistrict.text,
      'pat_address_district': _addrDistrict.text,
      'pat_address_province': _addrProvince.text,
      'pat_address_postcode': _addrPostcode.text,
      'pat_address_landmark': _addrLandmark.text,
      'pat_address_full': _buildFullAddress(_addrHouseNo, _addrMoo, _addrVillage, _addrSoi, _addrRoad, _addrSubdistrict, _addrDistrict, _addrProvince, _addrPostcode),
    };

    try {
      // ยิง API ครั้งที่ 1
      final res1 = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(addr1Data));
      
      bool success1 = false;
      if (res1.statusCode == 200) {
        final d1 = jsonDecode(res1.body);
        if (d1['success'] == true) success1 = true;
      }

      if (!success1) {
        _showFancySnack('บันทึกที่อยู่หลักไม่สำเร็จ: ${res1.body}');
        return; 
      }

      // --- บันทึกที่อยู่ 2 (ถ้าเปิดใช้งาน) ---
      if (_showSecondAddress) {
        final addr2Data = {
          ...personalData,
          // ✅ พิกัด 2 (ใช้ controller ชุดที่ 2)
          'pat_latitude': double.tryParse(_latitudeController2.text) ?? 0.0,
          'pat_longitude': double.tryParse(_longitudeController2.text) ?? 0.0,
          // ที่อยู่ 2
          'pat_address_house_no': _addrHouseNo2.text,
          'pat_address_moo': _addrMoo2.text,
          'pat_address_village': _addrVillage2.text,
          'pat_address_soi': _addrSoi2.text,
          'pat_address_road': _addrRoad2.text,
          'pat_address_subdistrict': _addrSubdistrict2.text,
          'pat_address_district': _addrDistrict2.text,
          'pat_address_province': _addrProvince2.text,
          'pat_address_postcode': _addrPostcode2.text,
          'pat_address_landmark': _addrLandmark2.text,
          'pat_address_full': _buildFullAddress(_addrHouseNo2, _addrMoo2, _addrVillage2, _addrSoi2, _addrRoad2, _addrSubdistrict2, _addrDistrict2, _addrProvince2, _addrPostcode2),
        };

        // ยิง API ครั้งที่ 2
        await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(addr2Data));
      }

      _showFancySnack('บันทึกข้อมูลเรียบร้อย!', success: true);
      _clearFields();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MapScreen()));

    } catch (e) {
      _showFancySnack('เกิดข้อผิดพลาด: $e');
    }
  }

  void _clearFields() {
    _nameController.clear(); _surnameController.clear(); _diseaseController.clear(); _startDateController.clear(); _sickDateController.clear(); _healingDateController.clear();
    _phoneNumberController.clear(); _latitudeController.clear(); _longitudeController.clear(); _dangerRangeController.clear();
    _descriptionController.clear(); _selectedDangerLevel = _dangerLevelOptions[0]; _dangerLevelController.text = _selectedDangerLevel!;
    
    // Clear Address 1
    _addrHouseNo.clear(); _addrMoo.clear(); _addrVillage.clear(); _addrSoi.clear(); _addrRoad.clear();
    _addrSubdistrict.clear(); _addrDistrict.clear(); _addrProvince.clear(); _addrPostcode.clear(); _addrLandmark.clear();
    
    // Clear Address 2 & Coords 2
    _addrHouseNo2.clear(); _addrMoo2.clear(); _addrVillage2.clear(); _addrSoi2.clear(); _addrRoad2.clear();
    _addrSubdistrict2.clear(); _addrDistrict2.clear(); _addrProvince2.clear(); _addrPostcode2.clear(); _addrLandmark2.clear();
    _latitudeController2.clear(); _longitudeController2.clear();

    setState(() {
      _submitted = false;
      _showSecondAddress = false; 
    });
  }

  // ... (Widget _buildLabel, _buildInputField, _buildDiseaseFieldHybrid เหมือนเดิม) ...
  Widget _buildLabel(String text, {bool required = false}) => RichText(text: TextSpan(text: text, style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 16), children: required ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : const []));

  Widget _buildInputField({required String labelText, required TextEditingController controller, String? Function(String?)? validator, IconData? suffixIcon, String? suffixText, VoidCallback? onTap, bool readOnly = false, bool required = false, TextInputType keyboardType = TextInputType.text}) {
    final List<TextInputFormatter>? fmts;
    if (controller == _addrMoo || controller == _addrMoo2) { fmts = [FilteringTextInputFormatter.digitsOnly]; } 
    else if (controller == _addrPostcode || controller == _addrPostcode2) { fmts = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)]; } 
    else if (keyboardType == const TextInputType.numberWithOptions(decimal: true)) { fmts = [FilteringTextInputFormatter.allow(RegExp(r'[\d\.\-]'))]; } 
    else { fmts = null; }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller, readOnly: readOnly, onTap: onTap, keyboardType: keyboardType, validator: validator, autovalidateMode: _submitted ? AutovalidateMode.always : AutovalidateMode.disabled, inputFormatters: fmts,
        decoration: InputDecoration(
          label: _buildLabel(labelText, required: required), errorStyle: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, height: 1.1),
          suffixIcon: suffixIcon != null ? IconButton(icon: Icon(suffixIcon, color: Colors.blueGrey), onPressed: onTap) : (suffixText != null ? Padding(padding: const EdgeInsets.only(right: 8.0, top: 14), child: Text(suffixText, style: const TextStyle(color: Colors.black87, fontSize: 16))) : null),
          border: const UnderlineInputBorder(), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey.shade300)), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _primary, width: 2)), errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red.shade400, width: 2)), focusedErrorBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red.shade600, width: 2)),
        ),
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
    );
  }

  Widget _buildDiseaseFieldHybrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _diseaseController, validator: (v) => _requiredText(v, 'โรค'), autovalidateMode: _submitted ? AutovalidateMode.always : AutovalidateMode.disabled, readOnly: false,
        decoration: InputDecoration(
          label: _buildLabel('ชื่อโรค', required: true), errorStyle: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, height: 1.1),
          suffixIcon: _loadingDiseases ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : IconButton(icon: const Icon(Icons.format_list_bulleted, color: Colors.blueGrey), onPressed: () async { if (_diseaseOptions.isEmpty) { _showFancySnack('ยังไม่มีรายการโรคจากฐานข้อมูล'); return; } FocusScope.of(context).unfocus(); final selected = await _showDiseasePickerWithSearch(); if (selected != null) { setState(() => _diseaseController.text = selected); if (_submitted) _formKey.currentState?.validate(); } }),
          border: const UnderlineInputBorder(), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey.shade300)), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _primary, width: 2)), errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red.shade400, width: 2)), focusedErrorBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red.shade600, width: 2)),
        ),
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
    );
  }

  // ===== Widget สำหรับฟอร์มที่อยู่ (Reusable) =====
  Widget _buildAddressFormSection({
    required TextEditingController house, required TextEditingController moo,
    required TextEditingController village, required TextEditingController soi,
    required TextEditingController road, required TextEditingController sub,
    required TextEditingController dist, required TextEditingController prov,
    required TextEditingController post, required TextEditingController land,
    bool isRequired = true,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildInputField(labelText: 'บ้านเลขที่', controller: house, validator: isRequired ? (v) => _requiredText(v, 'บ้านเลขที่') : null, required: isRequired)),
            const SizedBox(width: 12),
            Expanded(child: _buildInputField(labelText: 'หมู่', controller: moo, keyboardType: TextInputType.number, validator: isRequired ? (v) => _requiredText(v, 'หมู่') : null, required: isRequired)),
          ],
        ),
        _buildInputField(labelText: 'หมู่บ้าน/อาคาร', controller: village),
        Row(
          children: [
            Expanded(child: _buildInputField(labelText: 'ซอย', controller: soi)),
            const SizedBox(width: 12),
            Expanded(child: _buildInputField(labelText: 'ถนน', controller: road)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _buildInputField(labelText: 'ตำบล/แขวง', controller: sub, validator: isRequired ? (v) => _requiredText(v, 'ตำบล/แขวง') : null, required: isRequired)),
            const SizedBox(width: 12),
            Expanded(child: _buildInputField(labelText: 'อำเภอ/เขต', controller: dist, validator: isRequired ? (v) => _requiredText(v, 'อำเภอ/เขต') : null, required: isRequired)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _buildInputField(labelText: 'จังหวัด', controller: prov, validator: isRequired ? (v) => _requiredText(v, 'จังหวัด') : null, required: isRequired)),
            const SizedBox(width: 12),
            Expanded(child: _buildInputField(labelText: 'รหัสไปรษณีย์', controller: post, keyboardType: TextInputType.number, validator: isRequired ? _postcodeValidator : null, required: isRequired)),
          ],
        ),
        _buildInputField(labelText: 'จุดสังเกต', controller: land),
      ],
    );
  }

  // ===== Widget สำหรับพิกัด (Reusable) =====
  Widget _buildCoordinateSection({
    required TextEditingController latCtrl,
    required TextEditingController lngCtrl,
    bool isRequired = true,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildInputField(labelText: 'ละติจูด', controller: latCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: isRequired ? _requiredLat : null, required: isRequired),
              _buildInputField(labelText: 'ลองจิจูด', controller: lngCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: isRequired ? _requiredLng : null, required: isRequired),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 130,
          child: Center(
            child: IconButton(
              icon: const Icon(Icons.add_location_alt, color: _primary, size: 70),
              onPressed: () async {
                final LatLng? picked = await Navigator.push<LatLng>(
                  context,
                  MaterialPageRoute(builder: (_) => const MapScreen(markMode: true)),
                );
                if (picked != null) {
                  setState(() {
                    latCtrl.text = picked.latitude.toStringAsFixed(6);
                    lngCtrl.text = picked.longitude.toStringAsFixed(6);
                  });
                  // ถ้าเป็นชุดแรกให้เช็ค validate ทันที
                  if (latCtrl == _latitudeController && _submitted) {
                    _formKey.currentState?.validate();
                  }
                  _showFancySnack('เพิ่มพิกัดแล้ว', success: true);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Colors.white),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent, shadowColor: Colors.transparent, backgroundColor: const Color.fromARGB(0, 0, 0, 0), elevation: 0,
                leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: _primary, size: 24), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MapScreen()))),
                centerTitle: true, title: const Text('เพิ่มข้อมูลผู้ป่วย', style: TextStyle(color: _primary, fontSize: 28, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
                      decoration: BoxDecoration(color: const Color(0xFFEAF7FB), borderRadius: BorderRadius.circular(25), border: Border.all(color: _primary, width: 1.5)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  labelText: 'ชื่อ', 
                                  controller: _nameController, 
                                  validator: (v) => _requiredText(v, 'ชื่อ'), 
                                  required: true
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInputField(
                                  labelText: 'นามสกุล', 
                                  controller: _surnameController, 
                                  //validator: (v) => _requiredText(v, 'นามสกุล'), 
                                  //required: true
                                ),
                              ),
                            ],
                          ),
                          _buildDiseaseFieldHybrid(),
                          _buildInputField(labelText: 'วันรับเชื้อ', controller: _startDateController, readOnly: true, suffixIcon: Icons.calendar_month, onTap: () => _selectDate(context, _startDateController), validator: (v) => _requiredText(v, 'วันรับเชื้อ'), required: true),
                          _buildInputField(labelText: 'วันเริ่มป่วย', controller: _sickDateController, readOnly: true, suffixIcon: Icons.calendar_month, onTap: () => _selectDate(context, _sickDateController), required: true),
                          _buildInputField(labelText: 'วันสิ้นสุดการควบคุมโรค', controller: _healingDateController, readOnly: true, suffixIcon: Icons.calendar_month, onTap: () => _selectDate(context, _healingDateController), validator: (v) => _requiredText(v, 'วันสิ้นสุดการควบคุมโรค'), required: true),
                          _buildInputField(labelText: 'เบอร์โทรศัพท์', controller: _phoneNumberController, keyboardType: TextInputType.phone, validator: _phoneValidator, required: true),
                          _buildInputField(
                            labelText: 'ระดับความอันตราย', controller: _dangerLevelController, readOnly: true, suffixIcon: Icons.format_list_bulleted,
                            onTap: () async {
                              final selected = await showDialog<String>(context: context, builder: (ctx) => _popupTheme(ctx, SimpleDialog(title: const Text('เลือกระดับความอันตราย'), children: _dangerLevelOptions.map((e) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, e), child: Text(e))).toList())));
                              if (selected != null) setState(() { _selectedDangerLevel = selected; _dangerLevelController.text = selected; });
                            },
                          ),

                          const SizedBox(height: 15),
                          Align(alignment: Alignment.centerLeft, child: Text('ที่อยู่ปัจจุบัน', style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 18, fontWeight: FontWeight.w700))),
                          const SizedBox(height: 10),
                          
                          // --- พิกัด 1 ---
                          _buildCoordinateSection(latCtrl: _latitudeController, lngCtrl: _longitudeController, isRequired: true),
                          
                          const SizedBox(height: 6),
                          // --- ที่อยู่หลัก (1) ---
                          _buildAddressFormSection(
                            house: _addrHouseNo, moo: _addrMoo, village: _addrVillage, soi: _addrSoi, road: _addrRoad,
                            sub: _addrSubdistrict, dist: _addrDistrict, prov: _addrProvince, post: _addrPostcode, land: _addrLandmark,
                            isRequired: true,
                          ),

                          const SizedBox(height: 15),
                          
                          // --- ปุ่มเพิ่มที่อยู่ที่ 2 ---
                          if (!_showSecondAddress)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('เพิ่มที่อยู่ที่ 2'),
                                onPressed: () => setState(() => _showSecondAddress = true),
                              ),
                            ),

                          // --- ที่อยู่ที่ 2 (แสดงเมื่อกดปุ่ม) ---
                          if (_showSecondAddress) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('ที่อยู่ที่ 2', style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 18, fontWeight: FontWeight.w700)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => setState(() => _showSecondAddress = false),
                                  tooltip: 'ลบที่อยู่ที่ 2',
                                )
                              ],
                            ),
                            const SizedBox(height: 10),
                            
                            // ✅ พิกัดชุดที่ 2
                            _buildCoordinateSection(latCtrl: _latitudeController2, lngCtrl: _longitudeController2, isRequired: true),

                            const SizedBox(height: 6),
                            _buildAddressFormSection(
                              house: _addrHouseNo2, moo: _addrMoo2, village: _addrVillage2, soi: _addrSoi2, road: _addrRoad2,
                              sub: _addrSubdistrict2, dist: _addrDistrict2, prov: _addrProvince2, post: _addrPostcode2, land: _addrLandmark2,
                              isRequired: true, // บังคับกรอกถ้าเปิดฟอร์มนี้
                            ),
                            const SizedBox(height: 15),
                          ],

                          _buildInputField(labelText: 'ขอบเขตแพร่เชื้อของโรค', controller: _dangerRangeController, suffixText: 'เมตร', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _descriptionController, maxLines: 5,
                            decoration: InputDecoration(label: _buildLabel('คำอธิบาย เช่น รายละเอียดโรค อาการที่เป็น'), border: const OutlineInputBorder(), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: _primary)), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _primary, width: 2))),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 0),
                child: ElevatedButton(
                  onPressed: _validateAndSave,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, elevation: 0, backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: Ink(decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(15)), child: Container(alignment: Alignment.center, constraints: BoxConstraints(minWidth: size.width * 0.6, minHeight: 50), child: const Text('บันทึกข้อมูล', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)))),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}