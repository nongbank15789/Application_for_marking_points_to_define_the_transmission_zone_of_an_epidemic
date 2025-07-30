import 'package:flutter/material.dart';
import 'map_screen.dart';

class AddDataScreen extends StatefulWidget {
  const AddDataScreen({super.key});

  @override
  State<AddDataScreen> createState() => _AddDataScreenState();
}

class _AddDataScreenState extends State<AddDataScreen> {
  // Controllers สำหรับ TextField แต่ละช่อง (ถ้าต้องการดึงค่ามาใช้)
  // TextEditingController _nameController = TextEditingController(text: 'ธนพล อารามแก้ว');
  // TextEditingController _diseaseController = TextEditingController();
  // TextEditingController _startDateController = TextEditingController();
  // TextEditingController _phoneNumberController = TextEditingController(text: '1234567890');
  // TextEditingController _latitudeController = TextEditingController(text: '1234567890');
  // TextEditingController _longitudeController = TextEditingController(text: '1234567890');
  // TextEditingController _dangerRangeController = TextEditingController();
  // TextEditingController _descriptionController = TextEditingController();

  // State variable สำหรับค่าที่ถูกเลือกในช่อง "ระดับความอันตราย"
  String? _selectedDangerLevel; // ใช้ null ได้ถ้าไม่มีค่าเริ่มต้น

  // รายการตัวเลือกสำหรับ "ระดับความอันตราย"
  final List<String> _dangerLevelOptions = ['น้อย', 'ปานกลาง', 'มาก'];

  @override
  void initState() {
    super.initState();
    // กำหนดค่าเริ่มต้นสำหรับ "ระดับความอันตราย"
    _selectedDangerLevel = _dangerLevelOptions[0]; // เริ่มต้นเป็น 'น้อย'
  }

  @override
  void dispose() {
    // Dispose controllers เมื่อ Widget ถูกทำลายเพื่อป้องกัน Memory Leak
    // _nameController.dispose();
    // _diseaseController.dispose();
    // _startDateController.dispose();
    // _phoneNumberController.dispose();
    // _latitudeController.dispose();
    // _longitudeController.dispose();
    // _dangerRangeController.dispose();
    // _descriptionController.dispose();
    super.dispose();
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
            ], // สีฟ้าเข้มไปฟ้าอ่อน
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          // ใช้SafeArea เพื่อเนื้อหาไม่ทับ Status Bar
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent, // ทำให้AppBar โปร่งใส
                elevation: 0, // ไม่มีเงา
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
                centerTitle: true, // จัดTitle ให้อยู่ตรงกลาง
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
                  ), // Padding ซ้ายขวา
                  child: Container(
                    padding: const EdgeInsets.all(25), // Padding ภายในCard
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFE0F7FA,
                      ).withOpacity(0.9), // สีพื้นหลังของCard
                      borderRadius: BorderRadius.circular(25), // ขอบมน
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
                      mainAxisSize: MainAxisSize.min, // ใช้พื้นที่เท่าที่จำเป็น
                      children: [
                        _buildInputField(
                          label: 'ชื่อ',
                          initialValue: 'ธนพล อารามแก้ว',
                        ),
                        _buildInputField(
                          label: 'โรคที่ติด',
                          suffixIcon: Icons.format_list_bulleted,
                        ),
                        _buildInputField(label: 'วันที่ติด'),
                        _buildInputField(
                          label: 'เบอร์',
                          initialValue: '1234567890',
                        ),

                        // ช่อง "ระดับความอันตราย" ที่กดเลือกได้
                        _buildInputField(
                          label: 'ระดับความอันตราย',
                          initialValue:
                              _selectedDangerLevel, // แสดงค่าที่ถูกเลือก
                          suffixIcon: Icons.format_list_bulleted,
                          readOnly: true, // ทำให้เป็นแบบอ่านอย่างเดียว
                          options: _dangerLevelOptions, // ส่งตัวเลือกไป
                          onOptionSelected: (newValue) {
                            // callback เมื่อเลือก
                            setState(() {
                              _selectedDangerLevel = newValue;
                            });
                          },
                        ),

                        // ละติจูด ลองจิจูด และไอคอนตำแหน่ง
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .center, // จัดเรียงตรงกลางแนวตั้ง
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  _buildInputField(
                                    label: 'ละติจูด',
                                    initialValue: '1234567890',
                                  ),
                                  _buildInputField(
                                    label: 'ลองจิจูด',
                                    initialValue: '1234567890',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 130, // ปรับค่าความสูงนี้ตามความเหมาะสม
                              child: Center(
                                // จัดไอคอนให้อยู่ตรงกลางแนวตั้งของ SizedBox
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.add_location_alt,
                                    color: Colors.blue,
                                    size: 70,
                                  ), // เพิ่มขนาดไอคอน
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
                          suffixText: 'm.',
                        ), // <--- แก้ไขตรงนี้

                        const SizedBox(height: 15),

                        TextField(
                          maxLines: 5, // กำหนดให้มีหลายบรรทัด
                          decoration: InputDecoration(
                            labelText: 'คำอธิบาย',
                            labelStyle: TextStyle(
                              color: Colors.blueGrey.shade700,
                            ),
                            border: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blueGrey),
                            ),
                            enabledBorder: OutlineInputBorder(
                              // สีเส้นขอบเมื่อไม่ได้โฟกัส
                              borderSide: BorderSide(
                                color: Colors.blueGrey.shade300,
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              // สีเส้นขอบเมื่อโฟกัส
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
                onPressed: () {
                  // TODO: Implement save data action
                  String message =
                      'บันทึกข้อมูล:\n'
                      'ระดับความอันตราย: ${_selectedDangerLevel ?? "ไม่ได้เลือก"}';
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
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
    String? initialValue,
    IconData? suffixIcon,
    String? suffixText, // ตอนนี้ใช้สำหรับ 'm.'
    List<String>? options,
    ValueChanged<String>? onOptionSelected,
    bool readOnly = false,
  }) {
    // สร้าง TextEditingController เพื่อควบคุมค่าของ TextField
    final TextEditingController _textFieldController = TextEditingController(
      text: initialValue,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _textFieldController,
            readOnly: readOnly,
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
                        _textFieldController.text = selectedOption;
                        onOptionSelected?.call(selectedOption);
                      }
                    }
                    : null,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: Colors.blueGrey.shade700),

              // ******** แก้ไขตรงนี้ ********
              // ใช้ suffix แทน suffixIcon และ suffixText เพื่อให้ Widget อยู่ในบรรทัดเดียวกัน
              suffix: Row(
                mainAxisSize:
                    MainAxisSize.min, // สำคัญ: ให้ Row กินพื้นที่เท่าที่จำเป็น
                children: [
                  if (suffixIcon != null)
                    Icon(suffixIcon, color: Colors.blueGrey), // แสดง Icon ถ้ามี
                  if (suffixIcon != null && suffixText != null)
                    const SizedBox(width: 4), // ระยะห่างระหว่าง Icon กับ Text
                  if (suffixText != null)
                    Text(
                      suffixText,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                    ), // แสดง Text ถ้ามี
                ],
              ),

              // ***************************
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
