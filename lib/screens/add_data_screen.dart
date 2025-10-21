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
  // Form
  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;

  // ===== Date formats =====
  final DateFormat _fmtDisplay = DateFormat('dd/MM/yyyy'); // โชว์ในช่อง
  final DateFormat _fmtApi = DateFormat('yyyy-MM-dd');     // ส่งเข้า API

  // Controllers (ข้อมูลผู้ป่วย)
  final _nameController = TextEditingController();
  final _diseaseController = TextEditingController();
  final _startDateController = TextEditingController();
  final _healingDateController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _dangerRangeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dangerLevelController = TextEditingController();

  // Controllers (ที่อยู่)
  final _addrHouseNo = TextEditingController();      // *
  final _addrMoo = TextEditingController();          // *
  final _addrVillage = TextEditingController();
  final _addrSoi = TextEditingController();
  final _addrRoad = TextEditingController();
  final _addrSubdistrict = TextEditingController();  // *
  final _addrDistrict = TextEditingController();     // *
  final _addrProvince = TextEditingController();     // *
  final _addrPostcode = TextEditingController();     // *
  final _addrLandmark = TextEditingController();

  // Danger level
  String? _selectedDangerLevel;
  final List<String> _dangerLevelOptions = ['น้อย', 'ปานกลาง', 'มาก'];

  // Diseases from DB
  List<String> _diseaseOptions = [];
  bool _loadingDiseases = true;

  // Colors
  static const _primary = Color(0xFF0E47A1);

  // ===== Floating Banner (Overlay) =====
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

    if (widget.latitude != null) {
      _latitudeController.text = widget.latitude!.toStringAsFixed(6);
    }
    if (widget.longitude != null) {
      _longitudeController.text = widget.longitude!.toStringAsFixed(6);
    }

    _fetchDiseases();
  }

  @override
  void dispose() {
    _hideBanner();
    // ผู้ป่วย
    _nameController.dispose();
    _diseaseController.dispose();
    _startDateController.dispose();
    _healingDateController.dispose();
    _phoneNumberController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _dangerRangeController.dispose();
    _descriptionController.dispose();
    _dangerLevelController.dispose();
    // ที่อยู่
    _addrHouseNo.dispose();
    _addrMoo.dispose();
    _addrVillage.dispose();
    _addrSoi.dispose();
    _addrRoad.dispose();
    _addrSubdistrict.dispose();
    _addrDistrict.dispose();
    _addrProvince.dispose();
    _addrPostcode.dispose();
    _addrLandmark.dispose();
    super.dispose();
  }

  // ===== THEME for popups & datepicker =====
  Theme _popupTheme(BuildContext context, Widget child) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: const ColorScheme.light(
          primary: _primary,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titleTextStyle: const TextStyle(
            color: _primary, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _primary),
        ),
      ),
      child: child,
    );
  }

  // ===== Load diseases from API =====
  Future<void> _fetchDiseases() async {
    setState(() => _loadingDiseases = true);
    try {
      final res = await http.get(ApiConfig.u('add_data.php', {'mode': 'diseases'}),);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final setNames = <String>{};

        if (decoded is List) {
          for (final item in decoded) {
            final v = item is String
                ? item.trim()
                : (item is Map ? (item['name'] ?? item['disease'] ?? item['epidemic'] ?? item['title'])?.toString().trim() : null);
            if (v != null && v.isNotEmpty) setNames.add(v);
          }
        }

        if (!mounted) return;
        setState(() {
          _diseaseOptions = setNames.toList()..sort();
          _loadingDiseases = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _loadingDiseases = false;
          _diseaseOptions = [];
        });
        _showFancySnack('โหลดรายการโรคไม่สำเร็จ: ${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDiseases = false;
        _diseaseOptions = [];
      });
      _showFancySnack('เชื่อมต่อ API รายการโรคไม่สำเร็จ: $e');
    }
  }

  // ===== Dialog เลือกโรค + ค้นหา (with theme) =====
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
              void filter(String q) {
                query = q;
                final lower = q.toLowerCase();
                filtered = _diseaseOptions.where((e) => e.toLowerCase().contains(lower)).toList();
                setStateSB(() {});
              }

              return AlertDialog(
                title: const Text('เลือก ชื่อโรค'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'พิมพ์เพื่อค้นหา...',
                          prefixIcon: const Icon(Icons.search, color: _primary),
                          isDense: true,
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: _primary, width: 2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blueGrey.shade200),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: filter,
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: filtered.isEmpty
                            ? const Center(child: Text('ไม่พบรายการ'))
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final name = filtered[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                                    title: Text(name, style: const TextStyle(fontSize: 18)),
                                    onTap: () => Navigator.pop(dialogContext, name),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ยกเลิก')),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ===== Helper: แปลงวันที่ที่แสดง (dd/MM/yyyy) -> รูปแบบ API (yyyy-MM-dd) =====
  String _toApiDate(String input) {
    final s = input.trim();
    if (s.isEmpty) return s;
    DateTime? dt;

    // ลอง parse จากรูปแบบที่แสดง
    try { dt = _fmtDisplay.parseStrict(s); } catch (_) {}

    // เผื่อพิมพ์มาเป็น yyyy-MM-dd อยู่แล้ว
    if (dt == null) {
      try { dt = _fmtApi.parseStrict(s); } catch (_) {}
    }

    return dt != null ? _fmtApi.format(dt) : s;
  }

  // ===== Date picker (with theme) =====
  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (ctx, child) => _popupTheme(ctx, child!),
    );
    if (picked != null) {
      controller.text = _fmtDisplay.format(picked); // แสดงแบบ dd/MM/yyyy
      if (_submitted) _formKey.currentState?.validate();
    }
  }

  // ===== Validators =====
  String? _requiredText(String? v, String label) {
    if (v == null || v.trim().isEmpty) return 'กรุณากรอก$label';
    return null;
  }

  String? _requiredLat(String? v) {
    if (v == null || v.trim().isEmpty) return 'กรุณากรอกละติจูด';
    final x = double.tryParse(v);
    if (x == null) return 'รูปแบบไม่ถูกต้อง';
    if (x < -90 || x > 90) return 'ค่าต้องอยู่ระหว่าง -90 ถึง 90';
    return null;
  }

  String? _requiredLng(String? v) {
    if (v == null || v.trim().isEmpty) return 'กรุณากรอกลองจิจูด';
    final x = double.tryParse(v);
    if (x == null) return 'รูปแบบไม่ถูกต้อง';
    if (x < -180 || x > 180) return 'ค่าต้องอยู่ระหว่าง -180 ถึง 180';
    return null;
  }

  String? _phoneValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'กรุณากรอกเบอร์โทรศัพท์';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9 || digits.length > 11) return 'กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง';
    return null;
  }

  String? _postcodeValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'กรุณากรอกรหัสไปรษณีย์';
    final d = v.replaceAll(RegExp(r'\D'), '');
    if (d.length != 5) return 'รหัสไปรษณีย์ 5 หลัก';
    return null;
  }

  // ===== Save =====
  Future<void> _validateAndSave() async {
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showFancySnack('กรุณากรอกข้อมูลที่จำเป็นให้ครบ');
      return;
    }

    // รวมที่อยู่ให้อ่านง่าย
    final addressFull = [
      if (_addrHouseNo.text.trim().isNotEmpty) 'บ้านเลขที่ ${_addrHouseNo.text.trim()}',
      if (_addrMoo.text.trim().isNotEmpty) 'หมู่ ${_addrMoo.text.trim()}',
      if (_addrVillage.text.trim().isNotEmpty) 'หมู่บ้าน ${_addrVillage.text.trim()}',
      if (_addrSoi.text.trim().isNotEmpty) 'ซอย ${_addrSoi.text.trim()}',
      if (_addrRoad.text.trim().isNotEmpty) 'ถนน ${_addrRoad.text.trim()}',
      if (_addrSubdistrict.text.trim().isNotEmpty) 'ต.${_addrSubdistrict.text.trim()}',
      if (_addrDistrict.text.trim().isNotEmpty) 'อ.${_addrDistrict.text.trim()}',
      if (_addrProvince.text.trim().isNotEmpty) 'จ.${_addrProvince.text.trim()}',
      if (_addrPostcode.text.trim().isNotEmpty) _addrPostcode.text.trim(),
    ].join(' ');

    final url = ApiConfig.u('/add_data.php');

    final dataToSave = {
      // ผู้ป่วย
      'pat_name': _nameController.text,
      'pat_epidemic': _diseaseController.text.trim(),
      'pat_infection_date': _toApiDate(_startDateController.text),  // แปลงเป็น yyyy-MM-dd
      'pat_recovery_date': _toApiDate(_healingDateController.text), // แปลงเป็น yyyy-MM-dd
      'pat_phone': _phoneNumberController.text,
      'pat_danger_level': _selectedDangerLevel ?? 'ไม่ได้เลือก',
      'pat_latitude': double.tryParse(_latitudeController.text) ?? 0.0,
      'pat_longitude': double.tryParse(_longitudeController.text) ?? 0.0,
      'pat_danger_range': double.tryParse(_dangerRangeController.text) ?? 0.0,
      'pat_description': _descriptionController.text,

      // ที่อยู่
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
      'pat_address_full': addressFull,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(dataToSave),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          _showFancySnack('บันทึกข้อมูลสำเร็จ!', success: true);
          _clearFields();
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MapScreen()));
        } else {
          _showFancySnack('บันทึกข้อมูลล้มเหลว: ${responseData['message']}');
        }
      } else {
        _showFancySnack('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      _showFancySnack('เกิดข้อผิดพลาดในการเชื่อมต่อ: $e');
    }
  }

  void _clearFields() {
    // ผู้ป่วย
    _nameController.clear();
    _diseaseController.clear();
    _startDateController.clear();
    _healingDateController.clear();
    _phoneNumberController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _dangerRangeController.clear();
    _descriptionController.clear();
    _selectedDangerLevel = _dangerLevelOptions[0];
    _dangerLevelController.text = _selectedDangerLevel!;
    // ที่อยู่
    _addrHouseNo.clear();
    _addrMoo.clear();
    _addrVillage.clear();
    _addrSoi.clear();
    _addrRoad.clear();
    _addrSubdistrict.clear();
    _addrDistrict.clear();
    _addrProvince.clear();
    _addrPostcode.clear();
    _addrLandmark.clear();

    setState(() => _submitted = false);
  }

  // ===== Label with required asterisk =====
  Widget _buildLabel(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 16),
        children: required ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : const [],
      ),
    );
  }

  // ===== Generic input field =====
  Widget _buildInputField({
    required String labelText,
    required TextEditingController controller,
    String? Function(String?)? validator,
    IconData? suffixIcon,
    String? suffixText,
    VoidCallback? onTap,
    bool readOnly = false,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final List<TextInputFormatter>? fmts;
    if (controller == _addrMoo) {
      fmts = [FilteringTextInputFormatter.digitsOnly];
    } else if (controller == _addrPostcode) {
      fmts = [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ];
    } else if (keyboardType == const TextInputType.numberWithOptions(decimal: true)) {
      fmts = [FilteringTextInputFormatter.allow(RegExp(r'[\d\.\-]'))];
    } else {
      fmts = null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        validator: validator,
        autovalidateMode: _submitted ? AutovalidateMode.always : AutovalidateMode.disabled,
        inputFormatters: fmts,
        decoration: InputDecoration(
          label: _buildLabel(labelText, required: required),
          errorStyle: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, height: 1.1),
          suffixIcon: suffixIcon != null
              ? IconButton(icon: Icon(suffixIcon, color: Colors.blueGrey), onPressed: onTap)
              : (suffixText != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8.0, top: 14),
                      child: Text(suffixText, style: const TextStyle(color: Colors.black87, fontSize: 16)),
                    )
                  : null),
          border: const UnderlineInputBorder(),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey.shade300)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _primary, width: 2)),
          errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red.shade400, width: 2)),
          focusedErrorBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red.shade600, width: 2)),
        ),
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
    );
  }

  // ===== โรคที่ติด: พิมพ์ได้ + Popup มีค้นหา =====
  Widget _buildDiseaseFieldHybrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _diseaseController,
        validator: (v) => _requiredText(v, 'โรค'),
        autovalidateMode: _submitted ? AutovalidateMode.always : AutovalidateMode.disabled,
        readOnly: false,
        decoration: InputDecoration(
          label: _buildLabel('ชื่อโรค', required: true),
          errorStyle: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, height: 1.1),
          suffixIcon: _loadingDiseases
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.format_list_bulleted, color: Colors.blueGrey),
                  onPressed: () async {
                    if (_diseaseOptions.isEmpty) {
                      _showFancySnack('ยังไม่มีรายการโรคจากฐานข้อมูล');
                      return;
                    }
                    FocusScope.of(context).unfocus();
                    final selected = await _showDiseasePickerWithSearch();
                    if (selected != null) {
                      setState(() => _diseaseController.text = selected);
                      if (_submitted) _formKey.currentState?.validate();
                    }
                  },
                ),
          border: const UnderlineInputBorder(),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey.shade300)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _primary, width: 2)),
          errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red.shade400, width: 2)),
          focusedErrorBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red.shade600, width: 2)),
        ),
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
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
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                backgroundColor: const Color.fromARGB(0, 0, 0, 0),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: _primary, size: 24),
                  onPressed: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MapScreen()));
                  },
                ),
                centerTitle: true,
                title: const Text(
                  'เพิ่มข้อมูลผู้ป่วย',
                  style: TextStyle(color: _primary, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7FB),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: _primary, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.15), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildInputField(labelText: 'ชื่อผู้ป่วย', controller: _nameController, validator: (v) => _requiredText(v, 'ชื่อผู้ป่วย'), required: true),
                          _buildDiseaseFieldHybrid(),
                          _buildInputField(
                            labelText: 'วันที่ติด',
                            controller: _startDateController,
                            readOnly: true,
                            suffixIcon: Icons.calendar_month,
                            onTap: () => _selectDate(context, _startDateController),
                            validator: (v) => _requiredText(v, 'วันที่ติด'),
                            required: true,
                          ),
                          _buildInputField(
                            labelText: 'วันที่หาย',
                            controller: _healingDateController,
                            readOnly: true,
                            suffixIcon: Icons.calendar_month,
                            onTap: () => _selectDate(context, _healingDateController),
                            validator: (v) => _requiredText(v, 'วันที่หาย'),
                            required: true,
                          ),
                          _buildInputField(
                            labelText: 'เบอร์โทรศัพท์',
                            controller: _phoneNumberController,
                            keyboardType: TextInputType.phone,
                            validator: _phoneValidator,
                            required: true,
                          ),
                          _buildInputField(
                            labelText: 'ระดับความอันตราย',
                            controller: _dangerLevelController,
                            readOnly: true,
                            suffixIcon: Icons.format_list_bulleted,
                            onTap: () async {
                              final selected = await showDialog<String>(
                                context: context,
                                builder: (BuildContext dialogContext) {
                                  return _popupTheme(
                                    dialogContext,
                                    SimpleDialog(
                                      title: const Text('เลือกระดับความอันตราย'),
                                      children: _dangerLevelOptions
                                          .map((e) => SimpleDialogOption(
                                                onPressed: () => Navigator.pop(dialogContext, e),
                                                child: Text(e),
                                              ))
                                          .toList(),
                                    ),
                                  );
                                },
                              );
                              if (selected != null) {
                                setState(() {
                                  _selectedDangerLevel = selected;
                                  _dangerLevelController.text = selected;
                                });
                              }
                            },
                          ),

                          // พิกัด
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    _buildInputField(
                                      labelText: 'ละติจูด',
                                      controller: _latitudeController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      validator: _requiredLat,
                                      required: true,
                                    ),
                                    _buildInputField(
                                      labelText: 'ลองจิจูด',
                                      controller: _longitudeController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      validator: _requiredLng,
                                      required: true,
                                    ),
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
                                          _latitudeController.text = picked.latitude.toStringAsFixed(6);
                                          _longitudeController.text = picked.longitude.toStringAsFixed(6);
                                        });
                                        if (_submitted) _formKey.currentState?.validate();
                                        _showFancySnack('เพิ่มพิกัดจากแผนที่แล้ว', success: true);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // ฟอร์มที่อยู่
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('ที่อยู่', style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 18, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  labelText: 'บ้านเลขที่',
                                  controller: _addrHouseNo,
                                  validator: (v) => _requiredText(v, 'บ้านเลขที่'),
                                  required: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInputField(
                                  labelText: 'หมู่',
                                  controller: _addrMoo,
                                  keyboardType: TextInputType.number,
                                  validator: (v) => _requiredText(v, 'หมู่'),
                                  required: true,
                                ),
                              ),
                            ],
                          ),
                          _buildInputField(labelText: 'หมู่บ้าน/อาคาร', controller: _addrVillage),
                          Row(
                            children: [
                              Expanded(child: _buildInputField(labelText: 'ซอย', controller: _addrSoi)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildInputField(labelText: 'ถนน', controller: _addrRoad)),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  labelText: 'ตำบล/แขวง',
                                  controller: _addrSubdistrict,
                                  validator: (v) => _requiredText(v, 'ตำบล/แขวง'),
                                  required: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInputField(
                                  labelText: 'อำเภอ/เขต',
                                  controller: _addrDistrict,
                                  validator: (v) => _requiredText(v, 'อำเภอ/เขต'),
                                  required: true,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  labelText: 'จังหวัด',
                                  controller: _addrProvince,
                                  validator: (v) => _requiredText(v, 'จังหวัด'),
                                  required: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInputField(
                                  labelText: 'รหัสไปรษณีย์',
                                  controller: _addrPostcode,
                                  keyboardType: TextInputType.number,
                                  validator: _postcodeValidator,
                                  required: true,
                                ),
                              ),
                            ],
                          ),
                          _buildInputField(labelText: 'จุดสังเกต', controller: _addrLandmark),

                          // อื่น ๆ
                          _buildInputField(
                            labelText: 'ขอบเขตแพร่เชื้อของโรค',
                            controller: _dangerRangeController,
                            suffixText: 'เมตร',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              label: _buildLabel('คำอธิบาย เช่น รายละเอียดโรค อาการที่เป็น'),
                              border: const OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _primary.withOpacity(0.5))),
                              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _primary, width: 2)),
                            ),
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
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(15)),
                    child: Container(
                      alignment: Alignment.center,
                      constraints: BoxConstraints(minWidth: size.width * 0.6, minHeight: 50),
                      child: const Text(
                        'บันทึกข้อมูล',
                        style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
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
