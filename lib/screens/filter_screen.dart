import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  // ===== Theme =====
  static const Color kPrimary = Color(0xFF0277BD);
  static const Color kPrimaryDark = Color(0xFF0D47A1);
  static const Color kCardBg = Color(0xFFEAF7FB);
  static const Color kBorder = Color(0xFF9BD2E6);

  // ===== Animation =====
  static const _anim = Duration(milliseconds: 220);
  static const _curve = Curves.easeOutCubic;

  // ===== selections =====
  String _selectedInfectionFilter = 'ทั้งหมด';
  String _selectedRecoveryFilter = 'ทั้งหมด';
  String _selectedDiseaseFilter = 'ทั้งหมด';
  String _selectedDangerFilter = 'ทั้งหมด';

  // ===== constant options =====
  final List<String> _dateOptions = ['วันนี้', 'สัปดาห์นี้', 'เดือนนี้', 'ปีนี้', 'ทั้งหมด'];
  final List<String> _dangerOptions = ['น้อย', 'ปานกลาง', 'มาก', 'ทั้งหมด'];

  // ===== diseases (top-hit 3 + อื่น ๆ … + ทั้งหมด ล่างสุด) =====
  static const int TOP_HIT_COUNT = 3;
  bool _diseaseLoading = true;
  String? _diseaseLoadError;
  final Map<String, int> _diseaseFreq = {};
  List<String> _allDiseases = [];
  List<String> _topHits = [];
  List<String> _others = [];

  // ===== fixed layout (กัน UI ขยับ) =====
  static const double _cardRadius = 18;
  static const double _pillHeight = 40;
  static const double _pillSpacing = 10;
  static const int _verticalSlots = 5; // แสดง 5 แถวเสมอ
  static const double _verticalAreaHeight =
      _verticalSlots * _pillHeight + (_verticalSlots - 1) * _pillSpacing;

  @override
  void initState() {
    super.initState();
    _fetchDiseases();
  }

  Future<void> _fetchDiseases() async {
  setState(() {
    _diseaseLoading = true;
    _diseaseLoadError = null;
    _diseaseFreq.clear();
    _allDiseases.clear();
    _topHits.clear();
    _others.clear();
  });

  try {
    // ดึงผู้ป่วยทั้งหมด แล้วนับโรคจากฐานข้อมูลโดยตรง
    final res = await http.get(
      Uri.parse('http://10.0.2.2/api/get_all_patients.php'),
    );

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);

    // นับความถี่แบบ case-insensitive และตัดช่องว่าง/ค่าว่างทิ้ง
    final Map<String, int> freq = {};
    final Map<String, String> displayName = {}; // เก็บชื่อที่ใช้แสดง (รูปแบบแรกที่พบ)

    if (decoded is List) {
      for (final row in decoded) {
        final raw = (row['pat_epidemic'] ?? row['epidemic'])?.toString() ?? '';
        final s = raw.trim();
        if (s.isEmpty || s == 'ทั้งหมด') continue;

        final key = s.toLowerCase();     // ใช้ key ตัวพิมพ์เล็กเพื่อรวมค่าที่สะกดต่างกัน
        freq[key] = (freq[key] ?? 0) + 1;
        displayName[key] = displayName[key] ?? s; // เก็บชื่อที่อ่านง่ายไว้แสดง
      }
    }

    // จัดลำดับตามจำนวนคนที่ติดมาก → น้อย (ถ้าเท่ากันเรียงตามชื่อ)
    final entries = freq.entries.toList()
      ..sort((a, b) {
        if (b.value != a.value) return b.value.compareTo(a.value);
        return a.key.compareTo(b.key);
      });

    // รายชื่อทั้งหมด (ไว้ใช้ใน popup ค้นหา)
    final byCount = entries.map((e) => displayName[e.key]!).toList();
    final all = [...byCount]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    // 3 อันดับยอดฮิต + ที่เหลือ
    final top = byCount.take(TOP_HIT_COUNT).toList();
    final others = byCount.length > TOP_HIT_COUNT ? byCount.sublist(TOP_HIT_COUNT) : <String>[];

    if (!mounted) return;
    setState(() {
      _allDiseases = all;     // ใช้กับ popup ค้นหา
      _topHits = top;         // แสดงเป็นปุ่ม 3 อันดับในการ์ด
      _others = others;       // ถ้ามีค่อยแสดงปุ่ม "อื่น ๆ …"
      _diseaseLoading = false;

      // ถ้าค่าที่เลือกปัจจุบันหายไปจากรายการ ให้รีเซ็ตเป็น "ทั้งหมด"
      if (_selectedDiseaseFilter != 'ทั้งหมด' &&
          !_allDiseases.contains(_selectedDiseaseFilter)) {
        _selectedDiseaseFilter = 'ทั้งหมด';
      }
    });
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _diseaseLoading = false;
      _diseaseLoadError = 'โหลดรายการโรคไม่สำเร็จ: $e';
      _selectedDiseaseFilter = 'ทั้งหมด';
    });
  }
}


  void _resetAll() {
    setState(() {
      _selectedInfectionFilter = 'ทั้งหมด';
      _selectedRecoveryFilter = 'ทั้งหมด';
      _selectedDiseaseFilter = 'ทั้งหมด';
      _selectedDangerFilter = 'ทั้งหมด';
    });
  }

  Future<String?> _showDiseasePickerWithSearch() async {
    String q = '';
    List<String> filtered = List.of(_allDiseases);

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSB) {
            void filter(String s) {
              q = s;
              final lower = s.toLowerCase();
              filtered = _allDiseases
                  .where((e) => e.toLowerCase().contains(lower))
                  .toList();
              setSB(() {});
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
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
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: filter,
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: filtered.isEmpty
                          ? const Center(child: Text('ไม่พบรายการ'))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final name = filtered[i];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  title: Text(name,
                                      style: const TextStyle(
                                          fontSize: 18, height: 1.3)),
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
                    child: const Text('ยกเลิก')),
              ],
            );
          },
        );
      },
    );
  }

  // ===== Pill (แนวตั้ง) + animation check =====
  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity, // ยืดเต็มความกว้างการ์ดทุกตัว
      height: _pillHeight,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: _anim,
          curve: _curve,
          decoration: BoxDecoration(
            color: selected ? kPrimaryDark : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border:
                Border.all(color: selected ? kPrimaryDark : kBorder, width: 1.2),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: kPrimaryDark.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : const [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // พื้นที่ฟองติ๊กถูก (คงที่ 26px → UI ไม่สั่น)
              SizedBox(
                width: 26,
                child: AnimatedSwitcher(
                  duration: _anim,
                  transitionBuilder: (child, a) => ScaleTransition(
                    scale: CurvedAnimation(parent: a, curve: _curve),
                    child: FadeTransition(opacity: a, child: child),
                  ),
                  child: selected
                      ? Container(
                          key: const ValueKey('on'),
                          height: 22,
                          width: 22,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.check,
                                size: 16, color: kPrimaryDark),
                          ),
                        )
                      : const SizedBox(key: ValueKey('off')),
                ),
              ),
              if (icon != null) ...[
                Icon(icon,
                    size: 18,
                    color: selected ? Colors.white : Colors.black87),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardHeader(IconData icon, String title, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kPrimary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kPrimary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 16.5, fontWeight: FontWeight.w700, color: kPrimaryDark),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // การ์ดแนวตั้ง (วันที่ / ความอันตราย)
  Widget _verticalOptionsCard({
    required IconData icon,
    required String title,
    required List<String> options,
    required String selected,
    required void Function(String) onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 6)),
        ],
        border: Border.all(color: kBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(icon, title),
          const SizedBox(height: 12),
          SizedBox(
            height: _verticalAreaHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // ยืดปุ่มเต็มกว้าง
              children: [
                for (int i = 0; i < options.length; i++) ...[
                  _pill(
                    label: options[i],
                    selected: selected == options[i],
                    onTap: () => onSelected(options[i]),
                  ),
                  if (i != options.length - 1)
                    const SizedBox(height: _pillSpacing),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 18,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('เลือก: $selected',
                  style:
                      TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
            ),
          ),
        ],
      ),
    );
  }

  // การ์ด “โรคที่ติด”: top 3 → อื่น ๆ … → ทั้งหมด (ล่างสุด)
  Widget _diseaseCardVertical() {
    final List<Widget> buttons = [];

    for (final e in _topHits) {
      buttons.add(_pill(
        label: e,
        selected: _selectedDiseaseFilter == e,
        onTap: () => setState(() => _selectedDiseaseFilter = e),
      ));
      buttons.add(const SizedBox(height: _pillSpacing));
    }

    if (_others.isNotEmpty) {
      buttons.add(_pill(
        label: 'อื่น ๆ …',
        icon: Icons.format_list_bulleted,
        selected: false,
        onTap: () async {
          final picked = await _showDiseasePickerWithSearch();
          if (picked != null) {
            setState(() => _selectedDiseaseFilter = picked);
          }
        },
      ));
      buttons.add(const SizedBox(height: _pillSpacing));
    }

    buttons.add(_pill(
      label: 'ทั้งหมด',
      selected: _selectedDiseaseFilter == 'ทั้งหมด',
      onTap: () => setState(() => _selectedDiseaseFilter = 'ทั้งหมด'),
    ));

    // เติมให้ครบ 5 แถว (คงความสูงนิ่ง)
    final itemCount = (buttons.length + 1) ~/ 2; // ปุ่มจริง
    final fill = _verticalSlots - itemCount;
    for (int i = 0; i < fill; i++) {
      buttons.add(const SizedBox(height: _pillSpacing));
      buttons.add(const SizedBox(height: _pillHeight));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 6)),
        ],
        border: Border.all(color: kBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            Icons.coronavirus_rounded,
            'โรคที่ติด',
            trailing: _diseaseLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : (_diseaseLoadError != null
                    ? IconButton(
                        tooltip: 'ลองอีกครั้ง',
                        onPressed: _fetchDiseases,
                        icon: const Icon(Icons.refresh, size: 18, color: kPrimary),
                      )
                    : null),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _verticalAreaHeight,
            child: _diseaseLoading
                ? _diseaseSkeletonVertical()
                : SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch, // ยืดปุ่มเต็มกว้าง
                      children: buttons,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 18,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('เลือก: $_selectedDiseaseFilter',
                  style:
                      TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diseaseSkeletonVertical() {
    Widget box() => Container(
          height: _pillHeight,
          decoration: BoxDecoration(
            color: kBorder.withOpacity(0.55),
            borderRadius: BorderRadius.circular(28),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < _verticalSlots; i++) ...[
          box(),
          if (i != _verticalSlots - 1) const SizedBox(height: _pillSpacing),
        ],
      ],
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
                  icon: const Icon(Icons.arrow_back_ios,
                      color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
                centerTitle: true,
                title: const Text('ตัวกรองแผนที่',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
                actions: [
                  TextButton(
                    onPressed: _resetAll,
                    child: const Text('ล้างค่า',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ===== Layout 2 คอลัมน์ =====
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      EdgeInsets.symmetric(horizontal: size.width * 0.05),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _verticalOptionsCard(
                              icon: Icons.calendar_today_rounded,
                              title: 'ติดเชื้อภายใน',
                              options: _dateOptions,
                              selected: _selectedInfectionFilter,
                              onSelected: (v) =>
                                  setState(() => _selectedInfectionFilter = v),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _verticalOptionsCard(
                              icon: Icons.event_available_rounded,
                              title: 'หายจากโรคภายใน',
                              options: _dateOptions,
                              selected: _selectedRecoveryFilter,
                              onSelected: (v) =>
                                  setState(() => _selectedRecoveryFilter = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _diseaseCardVertical()),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _verticalOptionsCard(
                              icon: Icons.warning_amber_rounded,
                              title: 'ความอันตราย',
                              options: _dangerOptions,
                              selected: _selectedDangerFilter,
                              onSelected: (v) =>
                                  setState(() => _selectedDangerFilter = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ===== Confirm button =====
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final selected = {
                        'infectedDate': _selectedInfectionFilter,
                        'recoveryDate': _selectedRecoveryFilter,
                        'disease': _selectedDiseaseFilter,
                        'danger': _selectedDangerFilter,
                      };
                      Navigator.pop(context, selected);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF0277BD), Color(0xFF00BCD4)]),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Center(
                        child: Text('ยืนยัน',
                            style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
