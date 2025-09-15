import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'map_screen.dart';

class AddDataScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  const AddDataScreen({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<AddDataScreen> createState() => _AddDataScreenState();
}

class _AddDataScreenState extends State<AddDataScreen> {
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _diseaseController =
      TextEditingController(); // ค่าที่จะส่งไป API
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _healingDateController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _dangerRangeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dangerLevelController = TextEditingController();

  // Danger level (เลือกจากลิสต์เท่านั้น)
  String? _selectedDangerLevel;
  final List<String> _dangerLevelOptions = ['น้อย', 'ปานกลาง', 'มาก'];

  // Diseases from DB
  List<String> _diseaseOptions = [];
  bool _loadingDiseases = true;

  @override
  void initState() {
    super.initState();
    _selectedDangerLevel = _dangerLevelOptions[0];
    _dangerLevelController.text = _selectedDangerLevel!;
    _latitudeController.text = widget.latitude.toString();
    _longitudeController.text = widget.longitude.toString();
    _fetchDiseases();
  }

  @override
  void dispose() {
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
    super.dispose();
  }

  // ===== Load diseases from API =====
  Future<void> _fetchDiseases() async {
    setState(() => _loadingDiseases = true);
    try {
      final res = await http.get(
        Uri.parse('http://10.0.2.2/api/add_data.php?mode=diseases'),
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final setNames = <String>{};

        if (decoded is List) {
          for (final item in decoded) {
            final v =
                item is String
                    ? item.trim()
                    : (item is Map
                        ? (item['name'] ??
                                item['disease'] ??
                                item['epidemic'] ??
                                item['title'])
                            ?.toString()
                            .trim()
                        : null);
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
          _diseaseOptions = []; // ยังพิมพ์เองได้
        });
        _showSnackBar('โหลดรายการโรคไม่สำเร็จ: ${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDiseases = false;
        _diseaseOptions = [];
      });
      _showSnackBar('เชื่อมต่อ API รายการโรคไม่สำเร็จ: $e');
    }
  }

  // ===== Dialog เลือกโรค + ค้นหา =====
  Future<String?> _showDiseasePickerWithSearch() async {
    String query = '';
    List<String> filtered = List.of(_diseaseOptions);

    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            void filter(String q) {
              query = q;
              final lower = q.toLowerCase();
              filtered =
                  _diseaseOptions
                      .where((e) => e.toLowerCase().contains(lower))
                      .toList();
              setStateSB(() {});
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('เลือก โรคที่ติด'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'พิมพ์เพื่อค้นหา...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: filter,
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child:
                          filtered.isEmpty
                              ? const Center(child: Text('ไม่พบรายการ'))
                              : ListView.separated(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                separatorBuilder:
                                    (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final name = filtered[index];
                                  return ListTile(
                                    dense: false, // ให้มีความสูงแถวมากขึ้น
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 1, // เพิ่มพื้นที่แตะ
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize:
                                            18, // ← ปรับขนาดตัวอักษรตรงนี้ (เช่น 18–20)
                                        height: 1.3,
                                      ),
                                    ),
                                    onTap:
                                        () =>
                                            Navigator.pop(dialogContext, name),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ยกเลิก'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===== Date picker =====
  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  // ===== Save =====
  Future<void> _validateAndSave() async {
    if (_diseaseController.text.trim().isEmpty) {
      _showSnackBar('กรุณาระบุ โรคที่ติด');
      return;
    }
    if (_startDateController.text.isEmpty) {
      _showSnackBar('กรุณาระบุ วันที่ติด');
      return;
    }
    if (_latitudeController.text.isEmpty || _longitudeController.text.isEmpty) {
      _showSnackBar('กรุณาระบุพิกัด ละติจูด และ ลองจิจูด');
      return;
    }

    final url = Uri.parse('http://10.0.2.2/api/add_data.php');

    final dataToSave = {
      'pat_name': _nameController.text,
      'pat_epidemic':
          _diseaseController.text.trim(), // พิมพ์เองหรือเลือกจากลิสต์
      'pat_infection_date': _startDateController.text,
      'pat_recovery_date': _healingDateController.text,
      'pat_phone': _phoneNumberController.text,
      'pat_danger_level': _selectedDangerLevel ?? 'ไม่ได้เลือก',
      'pat_latitude': double.tryParse(_latitudeController.text) ?? 0.0,
      'pat_longitude': double.tryParse(_longitudeController.text) ?? 0.0,
      'pat_danger_range': double.tryParse(_dangerRangeController.text) ?? 0.0,
      'pat_description': _descriptionController.text,
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
          _showSnackBar('บันทึกข้อมูลสำเร็จ!');
          _clearFields();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MapScreen()),
          );
        } else {
          _showSnackBar('บันทึกข้อมูลล้มเหลว: ${responseData['message']}');
        }
      } else {
        _showSnackBar('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการเชื่อมต่อ: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearFields() {
    _nameController.clear();
    _startDateController.clear();
    _healingDateController.clear();
    _phoneNumberController.clear();
    _dangerRangeController.clear();
    _descriptionController.clear();
    _selectedDangerLevel = _dangerLevelOptions[0];
    _dangerLevelController.text = _selectedDangerLevel!;
    // _diseaseController ไม่ล้าง เพื่อให้ค่าที่พิมพ์คงอยู่ (หากต้องล้าง ให้ใส่ _diseaseController.clear();)
  }

  // ===== Generic input field (ใช้กับช่องอื่น ๆ) =====
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    IconData? suffixIcon,
    String? suffixText,
    VoidCallback? onTap,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        inputFormatters:
            keyboardType == const TextInputType.numberWithOptions(decimal: true)
                ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.-]'))]
                : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.blueGrey.shade700),
          suffixIcon:
              suffixIcon != null
                  ? IconButton(
                    icon: Icon(suffixIcon, color: Colors.blueGrey),
                    onPressed: onTap,
                  )
                  : (suffixText != null
                      ? Padding(
                        padding: const EdgeInsets.only(right: 8.0, top: 14),
                        child: Text(
                          suffixText,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      )
                      : null),
          border: const UnderlineInputBorder(),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blueGrey.shade300),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
        ),
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
    );
  }

  // ===== โรคที่ติด: พิมพ์ได้ + ขณะโหลดโชว์สปินเนอร์ + ไอคอนลิสต์เปิด popup (มีค้นหา) =====
  Widget _buildDiseaseFieldHybrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: _diseaseController,
        autofocus: false, // กันคีย์บอร์ดเด้งทันทีตอนเปิดหน้า
        decoration: InputDecoration(
          labelText: 'โรคที่ติด',
          labelStyle: TextStyle(color: Colors.blueGrey.shade700),
          suffixIcon:
              _loadingDiseases
                  ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                  : IconButton(
                    icon: const Icon(
                      Icons.format_list_bulleted,
                      color: Colors.blueGrey,
                    ),
                    onPressed: () async {
                      if (_diseaseOptions.isEmpty) {
                        _showSnackBar('ยังไม่มีรายการโรคจากฐานข้อมูล');
                        return;
                      }
                      FocusScope.of(context).unfocus(); // ปิดคีย์บอร์ดก่อน
                      final selected = await _showDiseasePickerWithSearch();
                      if (selected != null) {
                        setState(() => _diseaseController.text = selected);
                      }
                    },
                  ),
          border: const UnderlineInputBorder(),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blueGrey.shade300),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
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
        decoration: const BoxDecoration(color: Color(0xFFE6F5FC)),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                scrolledUnderElevation: 0,           // <- กันทึบเมื่อเลื่อน
                surfaceTintColor: Colors.transparent, // <- กันการใส่ tint
                shadowColor: Colors.transparent,
                backgroundColor: const Color.fromARGB(0, 0, 0, 0), // สีฟ้าอ่อนคงที่
                elevation: 0, // เพิ่มเงาเล็กน้อยให้ไม่โปร่งใส
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Color(0xFF0277BD),
                    size: 24,
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MapScreen()),
                    );
                  },
                ),
                centerTitle: true,
                title: const Text(
                  'เพิ่มข้อมูลผู้ป่วย',
                  style: TextStyle(
                    color: Color(0xFF0277BD),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F7FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Color.fromRGBO(
                          155,
                          210,
                          230,
                          1,
                        ), // ขอบฟ้าอ่อน
                        width: 1.5, // ความหนาของขอบ
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildInputField(
                          label: 'ชื่อ',
                          controller: _nameController,
                        ),

                        // ✅ โรคที่ติด: พิมพ์ได้ + Popup มีค้นหา
                        _buildDiseaseFieldHybrid(),

                        // วันที่
                        _buildInputField(
                          label: 'วันที่ติด',
                          controller: _startDateController,
                          readOnly: true,
                          suffixIcon: Icons.calendar_month,
                          onTap:
                              () => _selectDate(context, _startDateController),
                        ),
                        _buildInputField(
                          label: 'วันที่หาย',
                          controller: _healingDateController,
                          readOnly: true,
                          suffixIcon: Icons.calendar_month,
                          onTap:
                              () =>
                                  _selectDate(context, _healingDateController),
                        ),

                        _buildInputField(
                          label: 'เบอร์',
                          controller: _phoneNumberController,
                          keyboardType: TextInputType.phone,
                        ),

                        // ระดับความอันตราย: เหมือนเดิม (แตะช่อง/ไอคอนเพื่อเปิดลิสต์)
                        _buildInputField(
                          label: 'ระดับความอันตราย',
                          controller: _dangerLevelController,
                          readOnly: true,
                          suffixIcon: Icons.format_list_bulleted,
                          onTap: () async {
                            final selected = await showDialog<String>(
                              context: context,
                              builder: (BuildContext dialogContext) {
                                return SimpleDialog(
                                  title: const Text('เลือกระดับความอันตราย'),
                                  children:
                                      _dangerLevelOptions
                                          .map(
                                            (e) => SimpleDialogOption(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    dialogContext,
                                                    e,
                                                  ),
                                              child: Text(e),
                                            ),
                                          )
                                          .toList(),
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

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  _buildInputField(
                                    label: 'ละติจูด',
                                    controller: _latitudeController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                  _buildInputField(
                                    label: 'ลองจิจูด',
                                    controller: _longitudeController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 130,
                              child: Center(
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.add_location_alt,
                                    color: Colors.blue,
                                    size: 70,
                                  ),
                                  onPressed: () {
                                    /* ตำแหน่งถูกส่งมาจาก MapScreen อยู่แล้ว */
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),

                        _buildInputField(
                          label: 'ระยะอันตราย',
                          controller: _dangerRangeController,
                          suffixText: 'เมตร',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),

                        const SizedBox(height: 15),
                        TextField(
                          controller: _descriptionController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: 'คำอธิบาย',
                            labelStyle: TextStyle(
                              color: Colors.blueGrey.shade700,
                            ),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Color.fromRGBO(155, 210, 230, 1),
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _validateAndSave,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(size.width * 0.6, 50),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(13, 71, 161, 1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    constraints: BoxConstraints(
                      minWidth: size.width * 0.6,
                      minHeight: 50,
                    ),
                    child: const Text(
                      'บันทึกข้อมูล',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
