import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'map_screen.dart';
import 'package:intl/intl.dart';

// ================== MODEL ==================
class HistoryRecord {
  final int? id;
  final String? name;
  final String? disease;
  final String? startDate;
  final String? endDate;
  final String? phoneNumber;
  final String? dangerLevel;
  final String? description;
  final String? dangerRange;
  final String? latitude;
  final String? longitude;

  HistoryRecord({
    this.id,
    this.name,
    this.disease,
    this.startDate,
    this.endDate,
    this.phoneNumber,
    this.dangerLevel,
    this.description,
    this.dangerRange,
    this.latitude,
    this.longitude,
  });

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    return HistoryRecord(
      id: int.tryParse(json['pat_id'].toString()),
      name: json['pat_name'],
      disease: json['pat_epidemic'],
      startDate: json['pat_infection_date'],
      endDate: json['pat_recovery_date'],
      phoneNumber: json['pat_phone'],
      dangerLevel: json['pat_danger_level'],
      description: json['pat_description'],
      dangerRange: json['pat_danger_range'],
      latitude: json['pat_latitude'],
      longitude: json['pat_longitude'],
    );
  }
}

// ================== SCREEN ==================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<HistoryRecord>> futureHistory;

  @override
  void initState() {
    super.initState();
    futureHistory = fetchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<HistoryRecord>> fetchHistory([String? query]) async {
    final Map<String, dynamic> queryParameters = {};
    if (query != null && query.isNotEmpty) {
      queryParameters['search'] = query;
    }
    final uri = Uri.http(
      '10.0.2.2:80',
      '/api/get_history.php',
      queryParameters,
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => HistoryRecord.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to load history with status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  void _performSearch() {
    setState(() {
      futureHistory = fetchHistory(_searchController.text);
    });
  }

  void _showEditDialog(HistoryRecord record) {
    showDialog(
      context: context,
      builder:
          (_) => EditHistoryRecordDialog(
            record: record,
            onRecordUpdated: _performSearch,
            parentContext: context, // 🔹 ส่ง parent context เข้ามา
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 255, 255, 255),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                scrolledUnderElevation: 0, // <- กันทึบเมื่อเลื่อน
                surfaceTintColor: Colors.transparent, // <- กันการใส่ tint
                shadowColor: Colors.transparent,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Color(0xFF0E47A1),
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
                  'ประวัติผู้ป่วย',
                  style: TextStyle(
                    color: Color(0xFF0E47A1),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: 50,
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 255, 255, 255),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.5), // ขอบฟ้าอ่อน
                    width: 1.5, // ความหนาของขอบ
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 12.0,
                            horizontal: 6,
                          ),
                        ),
                        style: const TextStyle(color: Colors.black87),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.grey),
                      onPressed: _performSearch,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<HistoryRecord>>(
                  future: futureHistory,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final list = snapshot.data ?? [];
                    if (list.isEmpty) {
                      return const Center(child: Text('ไม่พบข้อมูลประวัติ'));
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          ...list.map(
                            (record) => Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildHistoryCard(
                                size,
                                record: record,
                                name: record.name ?? 'ไม่ระบุ',
                                disease: record.disease ?? 'ไม่ระบุ',
                                startDate: record.startDate ?? 'ไม่ระบุ',
                                endDate: record.endDate,
                                phoneNumber: record.phoneNumber ?? 'ไม่ระบุ',
                                dangerLevel: record.dangerLevel,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    Size size, {
    required HistoryRecord record,
    required String name,
    required String disease,
    required String startDate,
    String? endDate,
    required String phoneNumber,
    String? dangerLevel,
  }) {
    return Container(
      width: size.width * 0.9,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFEAF7FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFF0E47A1), // ขอบฟ้าอ่อน
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ชื่อ: $name',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF0D47A1),
                      size: 24,
                    ),
                    onPressed: () {
                      if (record.latitude != null && record.longitude != null) {
                        final lat = double.tryParse(record.latitude!);
                        final lng = double.tryParse(record.longitude!);
                        if (lat != null && lng != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) =>
                                      MapScreen(latitude: lat, longitude: lng),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('พิกัดไม่ถูกต้อง')),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ไม่มีข้อมูลพิกัด')),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.fullscreen_outlined,
                      color: Color(0xFF0D47A1),
                      size: 24,
                    ),
                    onPressed: () => _showEditDialog(record),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Color(0xFF0D47A1), thickness: 1, height: 10),
          const SizedBox(height: 8),
          _buildInfoRow('โรคที่ติด', disease),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildInfoRow('ติดวันที่', startDate)),
              const SizedBox(width: 20),
              Expanded(child: _buildInfoRow('หายวันที่', endDate ?? '-')),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow('เบอร์', phoneNumber),
          const SizedBox(height: 8),
          if (dangerLevel != null && dangerLevel.isNotEmpty)
            _buildInfoRow('ระดับความอันตราย', dangerLevel),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF084cc5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ],
    );
  }
}

// ================== EDIT DIALOG ==================
class EditHistoryRecordDialog extends StatefulWidget {
  final HistoryRecord record;
  final VoidCallback onRecordUpdated;
  final BuildContext parentContext; // 🔹 เพิ่ม

  const EditHistoryRecordDialog({
    super.key,
    required this.record,
    required this.onRecordUpdated,
    required this.parentContext, // 🔹 เพิ่ม
  });

  @override
  State<EditHistoryRecordDialog> createState() =>
      _EditHistoryRecordDialogState();
}

class _EditHistoryRecordDialogState extends State<EditHistoryRecordDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _diseaseController; // พิมพ์ได้
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _phoneNumberController;
  String? _selectedDangerLevel;
  late final TextEditingController
  _dangerLevelDisplayController; // แสดงค่าระดับความอันตราย (readOnly)
  late final TextEditingController _descriptionController;
  late final TextEditingController _dangerRangeController;

  // list โรคสำหรับ popup
  bool _diseaseLoading = false;
  String? _diseaseLoadError;
  List<String> _diseases = [];

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.record.name);
    _diseaseController = TextEditingController(
      text: widget.record.disease,
    ); // พิมพ์ได้
    _startDateController = TextEditingController(text: widget.record.startDate);
    _endDateController = TextEditingController(text: widget.record.endDate);
    _phoneNumberController = TextEditingController(
      text: widget.record.phoneNumber,
    );

    final levels = ['น้อย', 'ปานกลาง', 'มาก'];
    final r = widget.record.dangerLevel?.trim();
    _selectedDangerLevel = levels.contains(r) ? r : null;
    _dangerLevelDisplayController = TextEditingController(
      text: _selectedDangerLevel ?? '',
    );

    _descriptionController = TextEditingController(
      text: widget.record.description,
    );
    _dangerRangeController = TextEditingController(
      text: widget.record.dangerRange,
    );

    _loadDiseases();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _diseaseController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _phoneNumberController.dispose();
    _dangerLevelDisplayController.dispose();
    _descriptionController.dispose();
    _dangerRangeController.dispose();
    super.dispose();
  }

  // ---------- load diseases ----------
  Future<void> _loadDiseases() async {
    setState(() {
      _diseaseLoading = true;
      _diseaseLoadError = null;
      _diseases = [];
    });

    try {
      final res = await http.get(
        Uri.parse('http://10.0.2.2/api/get_all_patients.php'),
      );
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final decoded = jsonDecode(res.body);

      final set = <String>{};
      if (decoded is List) {
        for (final row in decoded) {
          final s =
              (row['pat_epidemic'] ?? row['epidemic'])?.toString().trim() ?? '';
          if (s.isNotEmpty && s.toLowerCase() != 'ทั้งหมด') set.add(s);
        }
      }
      final list =
          set.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _diseases = list;
        _diseaseLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _diseaseLoading = false;
        _diseaseLoadError = 'โหลดรายการโรคไม่สำเร็จ: $e';
      });
    }
  }

  // ---------- disease popup (ค้นหาได้) ----------
  Future<void> _openDiseasePicker() async {
    if (_diseases.isEmpty && !_diseaseLoading) {
      await _loadDiseases();
    }
    String q = '';
    List<String> filtered = List.of(_diseases);

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSB) {
            void filter(String s) {
              q = s;
              final lower = s.toLowerCase();
              filtered =
                  _diseases
                      .where((e) => e.toLowerCase().contains(lower))
                      .toList();
              setSB(() {});
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
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
                    if (_diseaseLoading)
                      const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_diseaseLoadError != null)
                      SizedBox(
                        height: 120,
                        child: Center(
                          child: Text(
                            _diseaseLoadError!,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child:
                            filtered.isEmpty
                                ? const Center(child: Text('ไม่พบรายการ'))
                                : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder:
                                      (_, __) => const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final name = filtered[i];
                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                      title: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          height: 1.3,
                                        ),
                                      ),
                                      onTap: () => Navigator.pop(ctx, name),
                                    );
                                  },
                                ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() {
        _diseaseController.text = picked; // ใส่ลงช่อง (ผู้ใช้ยังแก้ไขต่อได้)
      });
    }
  }

  // ---------- danger popup ----------
  Future<void> _openDangerPicker() async {
    const levels = ['น้อย', 'ปานกลาง', 'มาก'];
    final picked = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: const Color.fromARGB(255, 255, 255, 255),
            title: const Text('เลือกระดับความอันตราย'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    levels
                        .map(
                          (e) => ListTile(
                            leading: Icon(
                              _selectedDangerLevel == e
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: const Color(0xFF0077C2),
                            ),
                            title: Text(
                              e,
                              style: const TextStyle(fontSize: 18),
                            ),
                            onTap: () => Navigator.pop(ctx, e),
                          ),
                        )
                        .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก'),
              ),
            ],
          ),
    );

    if (picked != null) {
      setState(() {
        _selectedDangerLevel = picked;
        _dangerLevelDisplayController.text = picked;
      });
    }
  }

  // ---------- date ----------
  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    DateTime? initialDate;
    try {
      if (controller.text.isNotEmpty && controller.text != '0000-00-00') {
        final parsed = _dateFormat.parse(controller.text);
        initialDate = parsed.year >= 2000 ? parsed : DateTime.now();
      }
    } catch (_) {
      initialDate = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0E47A1), // สีหัวปฏิทิน + ปุ่มยืนยัน
              onPrimary: Colors.white, // สีตัวอักษรบนหัวปฏิทิน
              onSurface: Colors.black87
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF0E47A1), // สีปุ่ม CANCEL/OK
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => controller.text = _dateFormat.format(picked));
    }
  }

  // ---------- save/delete ----------
  Future<void> _saveChanges() async {
    if (_nameController.text.isEmpty) {
      _showError('กรุณาใส่ชื่อ');
      return;
    }
    if (_diseaseController.text.isEmpty) {
      _showError('กรุณาใส่โรคที่ติด');
      return;
    }
    if (_phoneNumberController.text.isEmpty) {
      _showError('กรุณาใส่เบอร์โทรศัพท์');
      return;
    }
    if (_dangerRangeController.text.isNotEmpty &&
        double.tryParse(_dangerRangeController.text) == null) {
      _showError('ระยะอันตรายต้องเป็นตัวเลขเท่านั้น');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final uri = Uri.http('10.0.2.2:80', '/api/update_history.php');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pat_id': widget.record.id,
          'pat_name': _nameController.text,
          'pat_epidemic': _diseaseController.text,
          'pat_infection_date': _startDateController.text,
          'pat_recovery_date': _endDateController.text,
          'pat_phone': _phoneNumberController.text,
          'pat_danger_level': _selectedDangerLevel,
          'pat_description': _descriptionController.text,
          'pat_danger_range': _dangerRangeController.text,
        }),
      );

      if (!mounted) return;
      Navigator.pop(context); // ปิด loading

      if (response.statusCode == 200) {
        widget.onRecordUpdated();
        if (!mounted) return;
        Navigator.pop(context); // ปิด dialog แก้ไข

        // แจ้งสำเร็จด้วย parentContext (ซึ่งยัง mounted)
        _showInfo('บันทึกข้อมูลเรียบร้อยแล้ว');
      } else {
        _showError(
          'Failed to update record with status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // ปิด loading ถ้ายังเปิดอยู่
      _showError('Error: $e');
    }
  }

  Future<void> _deleteRecord() async {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('ยืนยันการลบ'),
            content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลทั้งหมดนี้?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context); // ปิดกล่องยืนยัน
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (_) => const Center(child: CircularProgressIndicator()),
                  );

                  final uri = Uri.http(
                    '10.0.2.2:80',
                    '/api/delete_history.php',
                  );
                  try {
                    final res = await http.post(
                      uri,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({'id': widget.record.id}),
                    );

                    if (!mounted) return;
                    Navigator.pop(context); // ปิด loading

                    if (res.statusCode == 200) {
                      widget.onRecordUpdated();
                      if (!mounted) return;
                      Navigator.pop(context); // ปิด dialog แก้ไข
                      _showInfo('ลบข้อมูลเรียบร้อยแล้ว');
                    } else {
                      _showError(
                        'Failed to delete record with status code: ${res.statusCode}',
                      );
                    }
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(context); // ปิด loading
                    _showError('Error: $e');
                  }
                },
                child: const Text(
                  'ลบ',
                  style: TextStyle(color: Color.fromARGB(255, 26, 22, 22)),
                ),
              ),
            ],
          ),
    );
  }

  // ---------- dialogs ----------
  void _showError(String msg) {
    if (!mounted) return;
    showDialog(
      context: widget.parentContext, // 🔹 ใช้ parent
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              'ข้อผิดพลาด',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ตกลง'),
              ),
            ],
          ),
    );
  }

  void _showInfo(String msg) {
    if (!mounted) return;
    showDialog(
      context: widget.parentContext, // 🔹 ใช้ parent
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              'สำเร็จ',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ตกลง'),
              ),
            ],
          ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 1,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 10,
        contentPadding: const EdgeInsets.all(20),
        title: const Text(
          'แก้ไขข้อมูล',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0E47A1),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('ชื่อ', _nameController),
              const SizedBox(height: 16),

              // โรคที่ติด: พิมพ์ได้ + ไอคอนเปิด popup
              _buildDiseaseInputField(),
              const SizedBox(height: 16),

              _buildDatePickerField('ติดวันที่', _startDateController),
              const SizedBox(height: 16),
              _buildDatePickerField('หายวันที่', _endDateController),
              const SizedBox(height: 16),
              _buildTextField(
                'เบอร์',
                _phoneNumberController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // ระดับความอันตราย: popup
              _buildDangerPopupField(),
              const SizedBox(height: 16),

              _buildDescriptionField('คำอธิบาย', _descriptionController),
              const SizedBox(height: 16),
              _buildDangerRangeField('ระยะอันตราย', _dangerRangeController),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
              foregroundColor: Colors.grey[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: _deleteRecord,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('ลบ'),
          ),
          ElevatedButton(
            onPressed: _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E47A1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: const Color.fromARGB(255, 2, 3, 3)),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0E47A1), width: 2),
        ),
      ),
    );
  }

  // ---- Disease editable + popup button
  Widget _buildDiseaseInputField() {
    return TextField(
      controller: _diseaseController, // พิมพ์ได้
      decoration: InputDecoration(
        labelText: 'โรคที่ติด',
        labelStyle: TextStyle(color: Colors.blueGrey[700]),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0E47A1), width: 2),
        ),
        suffixIcon: IconButton(
          tooltip: 'เลือกรายการ',
          icon: const Icon(
            Icons.format_list_bulleted,
            color: Color(0xFF0E47A1),
          ),
          onPressed: _openDiseasePicker,
        ),
      ),
    );
  }

  // ---- Danger popup field (readOnly + popup)
  Widget _buildDangerPopupField() {
    return TextField(
      controller: _dangerLevelDisplayController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'ระดับความอันตราย',
        labelStyle: TextStyle(color: Colors.blueGrey[700]),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0E47A1), width: 2),
        ),
        suffixIcon: IconButton(
          tooltip: 'เลือกระดับ',
          icon: const Icon(
            Icons.format_list_bulleted,
            color: Color(0xFF0E47A1),
          ),
          onPressed: _openDangerPicker,
        ),
      ),
      onTap: _openDangerPicker,
    );
  }

  Widget _buildDescriptionField(
    String label,
    TextEditingController controller,
  ) {
    return TextField(
      controller: controller,
      maxLines: null,
      minLines: 3,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.blueGrey[700]),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0E47A1), width: 2),
        ),
      ),
    );
  }

  Widget _buildDatePickerField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.blueGrey[700]),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0E47A1), width: 2),
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today, color: Color(0xFF0E47A1)),
          onPressed: () => _selectDate(context, controller),
        ),
      ),
      onTap: () => _selectDate(context, controller),
    );
  }

  Widget _buildDangerRangeField(
    String label,
    TextEditingController controller,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.blueGrey[700]),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0E47A1), width: 2),
        ),
        suffixText: 'เมตร',
        suffixStyle: TextStyle(color: Colors.blueGrey[700]),
      ),
    );
  }
}
