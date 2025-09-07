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
  // Controllers for each TextField
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _diseaseController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _healingDateController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _dangerRangeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // State variable for the selected danger level
  String? _selectedDangerLevel;
  final List<String> _dangerLevelOptions = ['น้อย', 'ปานกลาง', 'มาก'];
  final List<String> _diseaseOptions = [
    'ไข้เลือดออก',
    'covid-19',
    'ไข้หวัดใหญ่',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDangerLevel = _dangerLevelOptions[0];

    // Check if latitude and longitude are passed and set them to the controllers
    _latitudeController.text = widget.latitude.toString();
    _longitudeController.text = widget.longitude.toString();
  }

  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
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

  // Function to select a date from the calendar
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
      // Use DateFormat to convert DateTime to the desired String format
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  // Function to validate and save data
  Future<void> _validateAndSave() async {
    // Check required data
    if (_diseaseController.text.isEmpty) {
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

    final url = Uri.parse(
      'http://10.0.2.2/api/add_data.php',
    ); // Change this URL

    Map<String, dynamic> dataToSave = {
      'pat_name': _nameController.text,
      'pat_epidemic': _diseaseController.text,
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

          // เคลียร์ข้อมูลในฟอร์ม
          _clearFields();
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

  // Function to show a SnackBar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearFields() {
    _diseaseController.clear();
    _startDateController.clear();
    _healingDateController.clear();
    _dangerRangeController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedDangerLevel = _dangerLevelOptions[0];
    });
  }

  // Helper widget for creating a TextField with a label and a divider line
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    IconData? suffixIcon,
    String? suffixText,
    List<String>? options,
    VoidCallback? onTap,
    ValueChanged<String>? onOptionSelected,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            readOnly: readOnly || options != null || onTap != null,
            onTap:
                options != null
                    ? () async {
                      final String? selectedOption = await showDialog<String>(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return SimpleDialog(
                            title: Text('เลือก $label'),
                            children:
                                options.map((String option) {
                                  return SimpleDialogOption(
                                    onPressed: () {
                                      Navigator.pop(dialogContext, option);
                                    },
                                    child: Text(option),
                                  );
                                }).toList(),
                          );
                        },
                      );
                      if (selectedOption != null) {
                        controller.text = selectedOption;
                        onOptionSelected?.call(selectedOption);
                      }
                    }
                    : onTap,
            keyboardType: keyboardType,
            inputFormatters:
                keyboardType == TextInputType.numberWithOptions(decimal: true)
                    ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.-]'))]
                    : null,
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
                  'เพิ่มข้อมูลผู้ป่วย',
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
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          options: _diseaseOptions,
                          onOptionSelected: (newValue) {
                            setState(() {
                              _diseaseController.text = newValue;
                            });
                          },
                        ),
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
                        ),
                        _buildInputField(
                          label: 'ระดับความอันตราย',
                          controller: TextEditingController(
                            text: _selectedDangerLevel,
                          ),
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
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                  _buildInputField(
                                    label: 'ลองจิจูด',
                                    controller: _longitudeController,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
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
                                    // Logic to get location can be here, but for this case,
                                    // the location is passed directly from MapScreen.
                                    // This button is not used to get the location in this flow.
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
}
