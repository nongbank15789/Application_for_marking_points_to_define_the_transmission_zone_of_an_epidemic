import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // เพิ่ม import นี้เพื่อใช้คลาส DateFormat
import 'map_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddDataScreen extends StatefulWidget {
  const AddDataScreen({super.key});

  @override
  State<AddDataScreen> createState() => _AddDataScreenState();
}

class _AddDataScreenState extends State<AddDataScreen> {
  // Controllers สำหรับ TextField แต่ละช่อง
  final TextEditingController _nameController = TextEditingController(text: 'ธนพล อารามแก้ว');
  final TextEditingController _diseaseController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _healingDateController = TextEditingController(); // เพิ่ม Controller สำหรับวันที่หาย
  final TextEditingController _phoneNumberController = TextEditingController(text: '1234567890');
  final TextEditingController _latitudeController = TextEditingController(text: '1234567890');
  final TextEditingController _longitudeController = TextEditingController(text: '1234567890');
  final TextEditingController _dangerRangeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // State variable สำหรับค่าที่ถูกเลือกในช่อง "ระดับความอันตราย"
  String? _selectedDangerLevel;
  final List<String> _dangerLevelOptions = ['น้อย', 'ปานกลาง', 'มาก'];

  @override
  void initState() {
    super.initState();
    _selectedDangerLevel = _dangerLevelOptions[0];
  }

  @override
  void dispose() {
    // Dispose controllers เมื่อ Widget ถูกทำลายเพื่อป้องกัน Memory Leak
    _nameController.dispose();
    _diseaseController.dispose();
    _startDateController.dispose();
    _healingDateController.dispose();
    _phoneNumberController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _dangerRangeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ฟังก์ชันสำหรับเลือกวันที่จากปฏิทิน
  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      // ใช้ DateFormat เพื่อแปลง DateTime เป็น String ในรูปแบบที่ต้องการ
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0077C2),
              Color(0xFF4FC3F7),
            ],
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
                  'เพิ่มข้อมูล',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F7FA).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(25),
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
                        _buildInputField(
                          label: 'โรคที่ติด',
                          controller: _diseaseController,
                          suffixIcon: Icons.format_list_bulleted,
                        ),
                        _buildInputField(
                          label: 'วันที่ติด',
                          controller: _startDateController,
                          readOnly: true, // ทำให้กดไม่ได้แต่เลือกจากปฏิทินได้
                          suffixIcon: Icons.calendar_month,
                          onTap: () => _selectDate(context, _startDateController),
                        ),
                        _buildInputField(
                          label: 'วันที่หาย', // เพิ่มช่องวันที่หาย
                          controller: _healingDateController,
                          readOnly: true,
                          suffixIcon: Icons.calendar_month,
                          onTap: () => _selectDate(context, _healingDateController),
                        ),
                        _buildInputField(
                          label: 'เบอร์',
                          controller: _phoneNumberController,
                        ),
                        _buildInputField(
                          label: 'ระดับความอันตราย',
                          controller: TextEditingController(text: _selectedDangerLevel),
                          readOnly: true,
                          suffixIcon: Icons.format_list_bulleted,
                          options: _dangerLevelOptions,
                          onOptionSelected: (newValue) {
                            setState(() {
                              _selectedDangerLevel = newValue;
                            });
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
                                  ),
                                  _buildInputField(
                                    label: 'ลองจิจูด',
                                    controller: _longitudeController,
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
                                    // TODO: Implement get location action
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        _buildInputField(
                          label: 'ระยะอันตราย',
                          controller: _dangerRangeController,
                          suffixText: 'm.',
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
                            border: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blueGrey),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.blueGrey.shade300,
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
                onPressed: () async {
                  String name = _nameController.text;
                  String disease = _diseaseController.text;
                  String startDate = _startDateController.text;
                  String healingDate = _healingDateController.text; // ดึงค่าวันที่หาย
                  String phoneNumber = _phoneNumberController.text;
                  String dangerLevel = _selectedDangerLevel ?? 'ไม่ได้เลือก';
                  double latitude = double.tryParse(_latitudeController.text) ?? 0.0;
                  double longitude = double.tryParse(_longitudeController.text) ?? 0.0;
                  double dangerRange = double.tryParse(_dangerRangeController.text) ?? 0.0;
                  String description = _descriptionController.text;

                  Map<String, dynamic> dataToSave = {
                    'name': name,
                    'disease': disease,
                    'startDate': startDate,
                    'healingDate': healingDate, // เพิ่มวันที่หายใน Map
                    'phoneNumber': phoneNumber,
                    'dangerLevel': dangerLevel,
                    'latitude': latitude,
                    'longitude': longitude,
                    'dangerRange': dangerRange,
                    'description': description,
                    'timestamp': FieldValue.serverTimestamp(),
                  };

                  try {
                    CollectionReference infectedPlaces = FirebaseFirestore.instance.collection('infected_places');
                    await infectedPlaces.add(dataToSave);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('บันทึกข้อมูลสำเร็จ!')),
                    );

                    _diseaseController.clear();
                    _startDateController.clear();
                    _healingDateController.clear();
                    _dangerRangeController.clear();
                    _descriptionController.clear();

                    setState(() {
                      _selectedDangerLevel = _dangerLevelOptions[0];
                    });
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')),
                    );
                  }
                },
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0277BD), Color(0xFF00BCD4)],
                    ),
                    borderRadius: BorderRadius.circular(30),
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

  // Helper widget สำหรับสร้าง TextField พร้อม Label และเส้นแบ่ง
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    IconData? suffixIcon,
    String? suffixText,
    List<String>? options,
    VoidCallback? onTap, // เพิ่ม onTap
    ValueChanged<String>? onOptionSelected,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            readOnly: readOnly || options != null, // ถ้าเป็นช่องสำหรับเลือก, ควรอ่านได้อย่างเดียว
            onTap: onTap, // ผูก onTap กับ TextField
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: Colors.blueGrey.shade700),
              suffix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (suffixIcon != null)
                    Icon(suffixIcon, color: Colors.blueGrey),
                  if (suffixIcon != null && suffixText != null)
                    const SizedBox(width: 4),
                  if (suffixText != null)
                    Text(
                      suffixText,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                ],
              ),
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blueGrey),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blueGrey.shade300),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue, width: 2),
              ),
            ),
            style: const TextStyle(color: Colors.black87, fontSize: 16),
          ),
        ],
      ),
    );
  }
}