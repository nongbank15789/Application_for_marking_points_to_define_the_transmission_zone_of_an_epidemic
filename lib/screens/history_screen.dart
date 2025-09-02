import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'map_screen.dart';
import 'package:intl/intl.dart';

// Model class to represent a history record
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
      id: int.tryParse(json['id'].toString()),
      name: json['name'],
      disease: json['disease'],
      startDate: json['startDate'],
      endDate: json['endDate'],
      phoneNumber: json['phoneNumber'],
      dangerLevel: json['dangerLevel'],
      description: json['description'],
      dangerRange: json['danger_range'],
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }
}

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
            'Failed to load history with status code: ${response.statusCode}');
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
      builder: (BuildContext context) {
        return EditHistoryRecordDialog(
          record: record,
          onRecordUpdated: () {
            _performSearch();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0077C2), Color(0xFF4FC3F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
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
                  'ประวัติ',
                  style: TextStyle(
                    color: Colors.white,
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
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(25),
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
                          hintStyle: TextStyle(color: Colors.blueGrey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 13.0),
                        ),
                        style: const TextStyle(color: Colors.black87),
                        onSubmitted: (value) => _performSearch(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.blueGrey),
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
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (snapshot.hasData) {
                      if (snapshot.data!.isEmpty) {
                        return const Center(child: Text('ไม่พบข้อมูลประวัติ'));
                      }
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            ...snapshot.data!.map(
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
                    } else {
                      return const Center(child: Text('ไม่พบข้อมูลประวัติ'));
                    }
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
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
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
                  color: Color(0xFF0077C2),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.location_on,
                      color: Color(0xFF4FC3F7),
                      size: 24,
                    ),
                    onPressed: () {
                      // TODO: Implement location view action
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.fullscreen,
                      color: Color(0xFF4FC3F7),
                      size: 24,
                    ),
                    onPressed: () {
                      _showEditDialog(record);
                    },
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Color(0xFFB0BEC5), thickness: 1, height: 20),
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4FC3F7),
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

class EditHistoryRecordDialog extends StatefulWidget {
  final HistoryRecord record;
  final VoidCallback onRecordUpdated;

  const EditHistoryRecordDialog({
    super.key,
    required this.record,
    required this.onRecordUpdated,
  });

  @override
  State<EditHistoryRecordDialog> createState() =>
      _EditHistoryRecordDialogState();
}

class _EditHistoryRecordDialogState extends State<EditHistoryRecordDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _diseaseController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _phoneNumberController;
  String? _selectedDangerLevel;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dangerRangeController;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.record.name);
    _diseaseController = TextEditingController(text: widget.record.disease);
    _startDateController = TextEditingController(text: widget.record.startDate);
    _endDateController = TextEditingController(text: widget.record.endDate);
    _phoneNumberController = TextEditingController(
      text: widget.record.phoneNumber,
    );

    final List<String> dangerLevels = ['น้อย', 'ปานกลาง', 'มาก'];
    final String? recordDangerLevel = widget.record.dangerLevel?.trim();
    _selectedDangerLevel =
        dangerLevels.contains(recordDangerLevel) ? recordDangerLevel : null;

    _descriptionController = TextEditingController(
      text: widget.record.description,
    );
    _dangerRangeController = TextEditingController(
      text: widget.record.dangerRange,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _diseaseController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _phoneNumberController.dispose();
    _descriptionController.dispose();
    _dangerRangeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    DateTime? initialDate;
    try {
      if (controller.text.isNotEmpty && controller.text != '0000-00-00') {
        final parsedDate = _dateFormat.parse(controller.text);
        if (parsedDate.year >= 2000) {
          initialDate = parsedDate;
        } else {
          initialDate = DateTime.now();
        }
      }
    } catch (e) {
      initialDate = DateTime.now();
    }

    final DateTime firstDate = DateTime(2000);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = _dateFormat.format(picked);
      });
    }
  }

  Future<void> _saveChanges() async {
    // Basic validation
    if (_nameController.text.isEmpty) {
      _showErrorDialog('กรุณาใส่ชื่อ');
      return;
    }
    if (_diseaseController.text.isEmpty) {
      _showErrorDialog('กรุณาใส่โรคที่ติด');
      return;
    }
    if (_phoneNumberController.text.isEmpty) {
      _showErrorDialog('กรุณาใส่เบอร์โทรศัพท์');
      return;
    }
    if (_dangerRangeController.text.isNotEmpty) {
      final dangerRange = double.tryParse(_dangerRangeController.text);
      if (dangerRange == null) {
        _showErrorDialog('ระยะอันตรายต้องเป็นตัวเลขเท่านั้น');
        return;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    final uri = Uri.http('10.0.2.2:80', '/api/update_history.php');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': widget.record.id,
          'name': _nameController.text,
          'disease': _diseaseController.text,
          'infected_date': _startDateController.text,
          'healing_date': _endDateController.text,
          'phone_number': _phoneNumberController.text,
          'danger_level': _selectedDangerLevel,
          'description': _descriptionController.text,
          'danger_range': _dangerRangeController.text,
        }),
      );

      Navigator.pop(context);

      if (response.statusCode == 200) {
        widget.onRecordUpdated();
        Navigator.pop(context);
        _showInfoDialog('บันทึกข้อมูลเรียบร้อยแล้ว');
      } else {
        _showErrorDialog(
            'Failed to update record with status code: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog('Error: $e');
    }
  }

  Future<void> _deleteRecord() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลทั้งหมดนี้?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const Center(child: CircularProgressIndicator());
                  },
                );

                final uri = Uri.http('10.0.2.2:80', '/api/delete_history.php');
                try {
                  final response = await http.post(
                    uri,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'id': widget.record.id}),
                  );

                  Navigator.pop(context);

                  if (response.statusCode == 200) {
                    widget.onRecordUpdated();
                    Navigator.pop(context);
                    _showInfoDialog('ลบข้อมูลเรียบร้อยแล้ว');
                  } else {
                    _showErrorDialog(
                        'Failed to delete record with status code: ${response.statusCode}');
                  }
                } catch (e) {
                  Navigator.pop(context);
                  _showErrorDialog('Error: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('ลบ', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'ข้อผิดพลาด',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('ตกลง'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'สำเร็จ',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('ตกลง'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.99,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        elevation: 10,
        contentPadding: const EdgeInsets.all(24),
        title: const Text(
          'แก้ไขข้อมูล',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0077C2),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('ชื่อ', _nameController),
              const SizedBox(height: 16),
              _buildTextField('โรคที่ติด', _diseaseController),
              const SizedBox(height: 16),
              _buildDatePickerField('ติดวันที่', _startDateController),
              const SizedBox(height: 16),
              _buildDatePickerField('หายวันที่', _endDateController),
              const SizedBox(height: 16),
              _buildTextField('เบอร์', _phoneNumberController,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildDangerLevelDropdown(),
              const SizedBox(height: 16),
              _buildDescriptionField('คำอธิบาย', _descriptionController),
              const SizedBox(height: 16),
              _buildDangerRangeField('ระยะอันตราย', _dangerRangeController),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.grey[700],
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
              backgroundColor: const Color(0xFF4FC3F7),
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

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.blueGrey[700]),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0077C2), width: 2),
        ),
      ),
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
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0077C2), width: 2),
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
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0077C2), width: 2),
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today, color: Color(0xFF0077C2)),
          onPressed: () => _selectDate(context, controller),
        ),
      ),
      onTap: () => _selectDate(context, controller),
    );
  }

  Widget _buildDangerLevelDropdown() {
    final List<String> dangerLevels = ['น้อย', 'ปานกลาง', 'มาก'];
    return DropdownButtonFormField<String>(
      value: _selectedDangerLevel,
      decoration: InputDecoration(
        labelText: 'ระดับความอันตราย',
        labelStyle: TextStyle(color: Colors.blueGrey[700]),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0077C2), width: 2),
        ),
      ),
      items: dangerLevels.map((String value) {
        return DropdownMenuItem<String>(value: value, child: Text(value));
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedDangerLevel = newValue;
        });
      },
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
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0077C2), width: 2),
        ),
        suffixText: 'm.',
        suffixStyle: TextStyle(color: Colors.blueGrey[700]),
      ),
    );
  }
}