import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
  static const Color kBorder = Color(0xFF0E47A1);

  // ===== Animation =====
  static const _anim = Duration(milliseconds: 220);
  static const _curve = Curves.easeOutCubic;

  // ===== selections =====
  DateTimeRange? _infectedRange; // ช่วง "ติดเชื้อภายใน"
  DateTimeRange? _recoveryRange; // ช่วง "หายจากโรคภายใน"
  String _selectedDiseaseFilter = 'ทั้งหมด';
  String _selectedDangerFilter = 'ทั้งหมด';

  // ===== diseases =====
  static const int TOP_HIT_COUNT = 3;
  bool _diseaseLoading = true;
  String? _diseaseLoadError;
  final Map<String, int> _diseaseFreq = {};
  List<String> _allDiseases = [];
  List<String> _topHits = [];
  List<String> _others = [];

  // ===== fixed layout =====
  static const double _cardRadius = 18;
  static const double _pillHeight = 40;
  static const double _pillSpacing = 10;
  static const int _verticalSlots = 5;
  static const double _verticalAreaHeight =
      _verticalSlots * _pillHeight + (_verticalSlots - 1) * _pillSpacing;

  // formatter: UI ไทย (ควรตั้ง default locale = th_TH ใน main.dart)
  final _fmtUi = DateFormat('d MMM yyyy');
  // formatter: ส่งต่อ API
  final _fmtApi = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _fetchDiseases();
  }

  // ====== ใช้ธีม popup ให้เหมือนหน้า AddDataScreen ======
  Theme _popupTheme(BuildContext context, Widget child) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        // สำคัญ: เซ็ตโทนสีให้ range ไม่เป็นฟ้า-เขียวของดีฟอลต์
        colorScheme: ColorScheme.light(
          primary: kPrimaryDark, // วงกลมวันที่ที่เลือก +ปุ่มยืนยัน
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black87,

          // ใช้เป็นพื้น "ช่วงวันที่" (แถบยาว ๆ)
          secondaryContainer: kPrimary.withOpacity(0.22),
          onSecondaryContainer: kPrimaryDark,
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: kPrimaryDark,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),

        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        datePickerTheme: DatePickerThemeData(
          // หัวปฏิทิน
          headerBackgroundColor: kPrimaryDark,
          headerForegroundColor: Colors.white,
          headerHeadlineStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          headerHelpStyle: const TextStyle(color: Colors.white70),

          // รูปทรงโดยรวม
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          // วันที่ปัจจุบัน/โฮเวอร์ (ลดทับสี)
          dayOverlayColor: const WidgetStatePropertyAll(Colors.transparent),

          // วงกลม “วันนี้”
          todayBorder: BorderSide(color: kPrimaryDark, width: 1.5),

          // (ทางเลือก) ให้วันที่ที่เลือกเป็นขาวบนพื้น primary ชัดขึ้น
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return null;
          }),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return kPrimaryDark;
            return null;
          }),
        ),
      ),
      // บังคับขนาด popup ให้พอดีเหมือนภาพตัวอย่าง (ไม่ใหญ่เกิน)
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 560),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20), // บังคับ child โค้งตามด้วย
            child: child,
          ),
        ),
      ),
    );
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
      final res = await http.get(
        Uri.parse('http://10.0.2.2/api/get_all_patients.php'),
      );
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final decoded = jsonDecode(res.body);
      final Map<String, int> freq = {};
      final Map<String, String> displayName = {};

      if (decoded is List) {
        for (final row in decoded) {
          final raw =
              (row['pat_epidemic'] ?? row['epidemic'])?.toString() ?? '';
          final s = raw.trim();
          if (s.isEmpty || s == 'ทั้งหมด') continue;
          final key = s.toLowerCase();
          freq[key] = (freq[key] ?? 0) + 1;
          displayName[key] = displayName[key] ?? s;
        }
      }

      final entries =
          freq.entries.toList()..sort((a, b) {
            if (b.value != a.value) return b.value.compareTo(a.value);
            return a.key.compareTo(b.key);
          });

      final byCount = entries.map((e) => displayName[e.key]!).toList();
      final all = [...byCount]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final top = byCount.take(TOP_HIT_COUNT).toList();
      final others =
          byCount.length > TOP_HIT_COUNT
              ? byCount.sublist(TOP_HIT_COUNT)
              : <String>[];

      if (!mounted) return;
      setState(() {
        _allDiseases = all;
        _topHits = top;
        _others = others;
        _diseaseLoading = false;

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
      _infectedRange = null;
      _recoveryRange = null;
      _selectedDiseaseFilter = 'ทั้งหมด';
      _selectedDangerFilter = 'ทั้งหมด';
    });
  }

  // ========= Date Range =========
  Future<void> _pickRange({required bool forInfection}) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 5, 1, 1);
    final lastDate = DateTime(now.year + 2, 12, 31);
    final initial = forInfection ? _infectedRange : _recoveryRange;

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          initial ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('th', 'TH'),
      helpText: 'เลือกวันที่', // บรรทัดหัวด้านซ้ายเหมือนในรูป
      cancelText: 'ยกเลิก',
      saveText: 'ตกลง',
      builder: (ctx, child) {
        // ใส่ธีม + บังคับขนาด dialog ให้คล้ายภาพตัวอย่าง
        return _popupTheme(
          ctx,
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360), // ขนาดพอดี
              child: child!,
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (forInfection) {
          _infectedRange = picked;
        } else {
          _recoveryRange = picked;
        }
      });
    }
  }

  String _rangeLabel(DateTimeRange? r) {
    if (r == null) return 'เลือกช่วงวันที่';
    return '${_fmtUi.format(r.start)}  -  ${_fmtUi.format(r.end)}';
  }

  // ========= Reusable UI =========
  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: _pillHeight,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: _anim,
          curve: _curve,
          decoration: BoxDecoration(
            color: selected ? kPrimaryDark : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: selected ? kPrimaryDark : const Color(0xFFFFFFFF),
              width: 1.2,
            ),
            boxShadow:
                selected
                    ? [
                      BoxShadow(
                        color: kPrimaryDark.withOpacity(0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : const [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: AnimatedSwitcher(
                  duration: _anim,
                  transitionBuilder:
                      (child, a) => ScaleTransition(
                        scale: CurvedAnimation(parent: a, curve: _curve),
                        child: FadeTransition(opacity: a, child: child),
                      ),
                  child:
                      selected
                          ? Container(
                            key: const ValueKey('on'),
                            height: 22,
                            width: 22,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: kPrimaryDark,
                              ),
                            ),
                          )
                          : const SizedBox(key: ValueKey('off')),
                ),
              ),
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : Colors.black87,
                ),
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
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: kPrimaryDark,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // ===== การ์ด "เลือกช่วงวันที่" =====
  // ===== การ์ด "เลือกช่วงวันที่" (compact เฉพาะ 2 บล็อกบน) =====
  Widget _dateRangeCard({
    required IconData icon,
    required String title,
    required DateTimeRange? value,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final selected = value != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FB),
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: kBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // หัวการ์ด
          _cardHeader(
            icon,
            title,
            trailing:
                selected
                    ? TextButton(
                      onPressed: onClear,
                      child: const Text('ล้างช่วง'),
                    )
                    : null,
          ),
          const SizedBox(height: 10),

          // ปุ่มช่วงวันที่ (ไม่มีการยืดความสูงคงที่อีกต่อไป)
          _pill(
            label: _rangeLabel(value),
            selected: selected,
            onTap: onPick,
            icon: Icons.date_range_rounded,
          ),

          // บรรทัดสรุปล่าง (ลดช่องว่างให้พอดี)
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              selected ? 'เลือก: ${_rangeLabel(value)}' : 'เลือก: ทั้งหมด',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  // ===== การ์ด “โรคที่ติด” =====
  Widget _diseaseCardVertical() {
    final List<Widget> buttons = [];

    for (final e in _topHits) {
      buttons
        ..add(
          _pill(
            label: e,
            selected: _selectedDiseaseFilter == e,
            onTap: () => setState(() => _selectedDiseaseFilter = e),
          ),
        )
        ..add(const SizedBox(height: _pillSpacing));
    }

    if (_others.isNotEmpty) {
      buttons
        ..add(
          _pill(
            label: 'อื่น ๆ …',
            icon: Icons.format_list_bulleted,
            selected: false,
            onTap: () async {
              final picked = await _showDiseasePickerWithSearch();
              if (picked != null)
                setState(() => _selectedDiseaseFilter = picked);
            },
          ),
        )
        ..add(const SizedBox(height: _pillSpacing));
    }

    buttons.add(
      _pill(
        label: 'ทั้งหมด',
        selected: _selectedDiseaseFilter == 'ทั้งหมด',
        onTap: () => setState(() => _selectedDiseaseFilter = 'ทั้งหมด'),
      ),
    );

    final itemCount = (buttons.length + 1) ~/ 2;
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
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: kBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            Icons.coronavirus_rounded,
            'โรคระบาด   ที่ติด',
            trailing:
                _diseaseLoading
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : (_diseaseLoadError != null
                        ? IconButton(
                          tooltip: 'ลองอีกครั้ง',
                          onPressed: _fetchDiseases,
                          icon: const Icon(
                            Icons.refresh,
                            size: 18,
                            color: Color(0xFF0277BD),
                          ),
                        )
                        : null),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _verticalAreaHeight,
            child:
                _diseaseLoading
                    ? _diseaseSkeletonVertical()
                    : SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: buttons,
                      ),
                    ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 18,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'เลือก: $_selectedDiseaseFilter',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showDiseasePickerWithSearch() async {
    String q = '';
    List<String> filtered = List.of(_allDiseases);

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return _popupTheme(
          ctx,
          StatefulBuilder(
            builder: (context, setSB) {
              void filter(String s) {
                q = s;
                final lower = s.toLowerCase();
                filtered =
                    _allDiseases
                        .where((e) => e.toLowerCase().contains(lower))
                        .toList();
                setSB(() {});
              }

              return AlertDialog(
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
                          prefixIcon: const Icon(
                            Icons.search,
                            color: kPrimaryDark,
                          ),
                          isDense: true,
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: kPrimaryDark,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.blueGrey.shade200,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: filter,
                      ),
                      const SizedBox(height: 10),
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
          ),
        );
      },
    );
  }

  Widget _diseaseSkeletonVertical() {
    Widget box() => Container(
      height: _pillHeight,
      decoration: BoxDecoration(
        color: kCardBg,
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

  // การ์ด "ความอันตราย"
  Widget _verticalOptionsCardDanger() {
    const options = ['น้อย', 'ปานกลาง', 'มาก', 'ทั้งหมด'];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FB),
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: kBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.warning_amber_rounded, 'ความอันตราย'),
          const SizedBox(height: 12),
          SizedBox(
            height: _verticalAreaHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < options.length; i++) ...[
                  _pill(
                    label: options[i],
                    selected: _selectedDangerFilter == options[i],
                    onTap:
                        () =>
                            setState(() => _selectedDangerFilter = options[i]),
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
              child: Text(
                'เลือก: $_selectedDangerFilter',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
            ),
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
        color: const Color(0xFFFFFFFF),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Color(0xFF0E47A1),
                    size: 25,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                centerTitle: true,
                title: const Text(
                  'ตัวกรองแผนที่',
                  style: TextStyle(
                    color: Color(0xFF0E47A1),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: _resetAll,
                    child: const Text(
                      'ล้างค่า',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ===== Layout 2 คอลัมน์ =====
              // ===== Layout (เปลี่ยนเป็นเต็มกว้างทีละใบ) =====
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
                  child: Column(
                    children: [
                      // การ์ดวันที่: เต็มกว้างทีละใบ
                      _dateRangeCard(
                        icon: Icons.calendar_today_rounded,
                        title: 'ติดเชื้อภายใน',
                        value: _infectedRange,
                        onPick: () => _pickRange(forInfection: true),
                        onClear: () => setState(() => _infectedRange = null),
                      ),
                      const SizedBox(height: 14),

                      _dateRangeCard(
                        icon: Icons.event_available_rounded,
                        title: 'หายจากโรคภายใน',
                        value: _recoveryRange,
                        onPick: () => _pickRange(forInfection: false),
                        onClear: () => setState(() => _recoveryRange = null),
                      ),
                      const SizedBox(height: 14),

                      // แถวล่าง: โรค/ความอันตราย (คงสองคอลัมน์ไว้)
                      Row(
                        children: [
                          Expanded(child: _diseaseCardVertical()),
                          const SizedBox(width: 14),
                          Expanded(child: _verticalOptionsCardDanger()),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // ===== Confirm button =====
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final selected = {
                        // สำหรับแสดงผล (คงคีย์เดิมไว้)
                        'infectedDate':
                            _infectedRange == null
                                ? 'ทั้งหมด'
                                : _rangeLabel(_infectedRange),
                        'recoveryDate':
                            _recoveryRange == null
                                ? 'ทั้งหมด'
                                : _rangeLabel(_recoveryRange),
                        'disease': _selectedDiseaseFilter,
                        'danger': _selectedDangerFilter,

                        // สำหรับยิง API (ใหม่)
                        'infectedStart':
                            _infectedRange == null
                                ? null
                                : _fmtApi.format(_infectedRange!.start),
                        'infectedEnd':
                            _infectedRange == null
                                ? null
                                : _fmtApi.format(_infectedRange!.end),
                        'recoveryStart':
                            _recoveryRange == null
                                ? null
                                : _fmtApi.format(_recoveryRange!.start),
                        'recoveryEnd':
                            _recoveryRange == null
                                ? null
                                : _fmtApi.format(_recoveryRange!.end),
                      };
                      Navigator.pop(context, selected);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E47A1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Center(
                        child: Text(
                          'ยืนยัน',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
