import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'map_screen.dart';
import 'config.dart';

final _getEndpoint = '/get_history.php'; // ไฟล์นี้ดึงเฉพาะ patient (ติดเชื้อ)
final _updateEndpoint = '/save_patient.php';
final _deleteEndpoint = '/delete_history.php';

// ===== Theme helpers for badge & app =====
const _primary = Color(0xFF0E47A1);
const _ok = Color(0xFF2E7D32); // เขียว
const _warn = Color(0xFFF57C00); // ส้ม
const _danger = Color(0xFFD32F2F); // แดง
const _chipBg = Color(0xFFF3F6FF); // พื้นจาง ๆ

class InfectedRecord {
  final int? id;
  final String? name,
      surname, // <--- [เพิ่ม] นามสกุล
      disease,
      sickDate,
      startDate,
      endDate,
      phoneNumber,
      dangerLevel,
      description,
      dangerRange,
      latitude,
      longitude;

  // address parts
  final String? houseNo,
      soi,
      road,
      village,
      moo,
      subdistrict,
      district,
      province,
      postcode,
      landmark;

  InfectedRecord({
    this.id,
    this.name,
    this.surname, // <--- [เพิ่ม]
    this.disease,
    this.sickDate,
    this.startDate,
    this.endDate,
    this.phoneNumber,
    this.dangerLevel,
    this.description,
    this.dangerRange,
    this.latitude,
    this.longitude,
    this.houseNo,
    this.soi,
    this.road,
    this.village,
    this.moo,
    this.subdistrict,
    this.district,
    this.province,
    this.postcode,
    this.landmark,
  });

  factory InfectedRecord.fromJson(Map<String, dynamic> j) => InfectedRecord(
        id: int.tryParse(j['pat_id'].toString()),
        name: j['pat_name'],
        surname: j['pat_surname'], // <--- [รับค่าจาก API]
        disease: j['pat_epidemic'],
        sickDate: j['pat_sick_date'],
        startDate: j['pat_infection_date'],
        endDate: j['pat_recovery_date'],
        phoneNumber: j['pat_phone'],
        dangerLevel: j['pat_danger_level'],
        description: j['pat_description'],
        dangerRange: j['pat_danger_range'],
        latitude: j['pat_latitude'],
        longitude: j['pat_longitude'],
        houseNo: j['pat_address_house_no'],
        soi: j['pat_address_soi'],
        road: j['pat_address_road'],
        village: j['pat_address_village'],
        moo: j['pat_address_moo'],
        subdistrict: j['pat_address_subdistrict'],
        district: j['pat_address_district'],
        province: j['pat_address_province'],
        postcode: j['pat_address_postcode'],
        landmark: j['pat_address_landmark'],
      );

  String fullAddress() {
    final p = <String>[
      if ((houseNo ?? '').trim().isNotEmpty) 'บ้านเลขที่ $houseNo',
      if ((moo ?? '').trim().isNotEmpty) 'หมู่ $moo',
      if ((village ?? '').trim().isNotEmpty) village!,
      if ((soi ?? '').trim().isNotEmpty) 'ซอย $soi',
      if ((road ?? '').trim().isNotEmpty) 'ถนน $road',
      if ((subdistrict ?? '').trim().isNotEmpty) 'ต.$subdistrict',
      if ((district ?? '').trim().isNotEmpty) 'อ.$district',
      if ((province ?? '').trim().isNotEmpty) 'จ.$province',
      if ((postcode ?? '').trim().isNotEmpty) postcode!,
    ];
    return p.join(' ');
  }
}

class InfectedHistoryScreen extends StatefulWidget {
  const InfectedHistoryScreen({super.key});
  @override
  State<InfectedHistoryScreen> createState() => _InfectedHistoryScreenState();
}

class _InfectedHistoryScreenState extends State<InfectedHistoryScreen> {
  final _search = TextEditingController();
  late Future<List<InfectedRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _isRecovered(String? recoveryDate) {
    if (recoveryDate == null) return false;
    final s = recoveryDate.trim();
    if (s.isEmpty || s == '0000-00-00') return false;
    try {
      final dt = s.length == 10
          ? DateFormat('yyyy-MM-dd').parseStrict(s)
          : DateTime.parse(s);
      final endOfDay = DateTime(dt.year, dt.month, dt.day, 23, 59, 59);
      return DateTime.now().isAfter(endOfDay) ||
          DateTime.now().isAtSameMomentAs(endOfDay);
    } catch (_) {
      return false;
    }
  }

  Future<List<InfectedRecord>> _fetch([String? q]) async {
    final qp = <String, String>{};
    if ((q ?? '').isNotEmpty) qp['search'] = q!;
    final uri = ApiConfig.u(_getEndpoint, qp);
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed: ${res.statusCode} ${res.body}');
    }
    final List data = jsonDecode(res.body);
    return data
        .cast<Map<String, dynamic>>()
        .map((e) => InfectedRecord.fromJson(e))
        .where((r) => !_isRecovered(r.endDate)) // กรองเฉพาะที่ยังไม่หาย
        .toList();
  }

  void _doSearch() {
    setState(() {
      _future = _fetch(_search.text);
    });
  }

  void _openEdit(InfectedRecord r) {
    showDialog(
      context: context,
      builder: (_) => _EditDialogInfected(record: r, onSaved: _doSearch),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppBar(
              scrolledUnderElevation: 0,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: _primary),
                onPressed: () => Navigator.pop(context),
              ),
              centerTitle: true,
              title: const Text(
                'ประวัติผู้ป่วย (ติดเชื้ออยู่)',
                style: TextStyle(
                  color: _primary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SearchBar(controller: _search, onSearch: _doSearch),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<InfectedRecord>>(
                future: _future,
                builder: (_, s) {
                  if (s.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (s.hasError) {
                    return Center(child: Text('Error: ${s.error}'));
                  }
                  final list = s.data ?? [];
                  if (list.isEmpty) {
                    return const Center(child: Text('ไม่พบข้อมูล'));
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        ...list.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _HistoryCard(
                              size: size,
                              // ✅ ส่งชื่อ + นามสกุล
                              title: '${r.name ?? ''} ${r.surname ?? ''}'.trim(),
                              disease: r.disease ?? '-',
                              sickDate: r.sickDate ?? '-',
                              startDate: r.startDate ?? '-',
                              endDate: r.endDate ?? '-',
                              phone: r.phoneNumber ?? '-',
                              dangerLevel: r.dangerLevel,
                              address: r.fullAddress(),
                              lat: r.latitude,
                              lng: r.longitude,
                              onEdit: () => _openEdit(r),
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
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  const _SearchBar({required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'ค้นหา...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 6,
                ),
              ),
              style: const TextStyle(color: Colors.black87),
              onSubmitted: (_) => onSearch(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.grey),
            onPressed: onSearch,
          ),
        ],
      ),
    );
  }
}

// ===== Helpers for "อีกกี่วันหาย"
int _daysUntil(String? endDate) {
  if (endDate == null || endDate.trim().isEmpty) return 0;
  final s = endDate.trim();
  // ถ้ามีแต่ yyyy-MM-dd ให้เติมเวลา เพื่อให้ parse ได้
  final dt = DateTime.tryParse(s.length == 10 ? '$s 00:00:00' : s);
  if (dt == null) return 0;
  final now = DateTime.now();
  // คิดความต่างเป็นวัน
  return dt.difference(DateTime(now.year, now.month, now.day)).inDays;
}

({String text, Color color}) recoveryNoteAndColor(String? endDate) {
  final d = _daysUntil(endDate);
  if (d < 0) return (text: 'เลยกำหนด ${-d} วัน', color: _ok);
  if (d == 0) return (text: 'หายวันนี้', color: _ok);
  if (d <= 3) return (text: 'หายอีก $d วัน', color: _ok);
  if (d <= 7) return (text: 'หายอีก $d วัน', color: _warn);
  return (text: 'หายอีก $d วัน', color: _danger);
}

class _HistoryCard extends StatelessWidget {
  final Size size;
  final String title, disease, sickDate, startDate, endDate, phone;
  final String? dangerLevel;
  final String address;
  final String? lat, lng;
  final VoidCallback onEdit;

  const _HistoryCard({
    required this.size,
    required this.title,
    required this.disease,
    required this.sickDate,
    required this.startDate,
    required this.endDate,
    required this.phone,
    required this.dangerLevel,
    required this.address,
    required this.lat,
    required this.lng,
    required this.onEdit,
  });

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = recoveryNoteAndColor(endDate);

    return Container(
      width: size.width * 0.9,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ชื่อ + ปุ่ม Map/Edit
          Row(
            crossAxisAlignment: CrossAxisAlignment.start, // ✅ จัดให้ชิดบน เพื่อไม่ให้ปุ่มเลื่อนตามความสูง text
            children: [
              // ส่วนแสดงชื่อ (ใช้ Expanded เพื่อให้กินพื้นที่ที่เหลือและตัดคำได้)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // แสดงชื่อ
                    Text(
                      'ชื่อ: ${title.split(' ').first}', // ดึงคำแรก (ชื่อ)
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4), // เว้นระยะห่างนิดหน่อย
                    // แสดงนามสกุล
                    Text(
                      'นามสกุล: ${title.split(' ').length > 1 ? title.split(' ').sublist(1).join(' ') : '-'}', // ดึงคำที่เหลือ (นามสกุล)
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.location_on_outlined, color: _primary),
                    onPressed: () {
                      final la = double.tryParse(lat ?? '');
                      final lo = double.tryParse(lng ?? '');
                      if (la != null && lo != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MapScreen(latitude: la, longitude: lo),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('พิกัดไม่ถูกต้อง')),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: _primary),
                    onPressed: onEdit,
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: _primary, thickness: 1, height: 10),
          const SizedBox(height: 8),

          // โรคที่ติด + badge สถานะ
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _row('โรคที่ติด', disease)),
              const SizedBox(width: 8),
              _badge(info.text, info.color),
            ],
          ),
          const SizedBox(height: 10),

          // วันเริ่มป่วย (ซ้าย) | วันรับเชื้อ (ขวา)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _row('วันเริ่มป่วย', sickDate)),
              const SizedBox(width: 20),
              Expanded(child: _row('วันรับเชื้อ', startDate)),
            ],
          ),
          const SizedBox(height: 10),

          // วันสิ้นสุดการควบคุมโรค (ชิดซ้ายเดี่ยวๆ)
          _row('วันสิ้นสุดการควบคุมโรค', endDate),

          const SizedBox(height: 10),
          _row('เบอร์', phone),
          const SizedBox(height: 8),

          if ((dangerLevel ?? '').isNotEmpty)
            _row('ระดับความอันตราย', dangerLevel!),
          const SizedBox(height: 8),

          _row('ที่อยู่', address.isEmpty ? '-' : address),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Column(
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
          Text(value,
              style: const TextStyle(fontSize: 16, color: Colors.black87)),
        ],
      );
}

// ==================== EDIT DIALOG ====================
class _EditDialogInfected extends StatefulWidget {
  final InfectedRecord record;
  final VoidCallback onSaved;
  const _EditDialogInfected({required this.record, required this.onSaved});

  @override
  State<_EditDialogInfected> createState() => _EditDialogInfectedState();
}

class _EditDialogInfectedState extends State<_EditDialogInfected> {
  static const _primary = Color(0xFF0E47A1);

  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;

  final DateFormat _fmtDisplay = DateFormat('dd/MM/yyyy');
  final DateFormat _fmtApi = DateFormat('yyyy-MM-dd');

  final List<String> _dangerLevelOptions = ['ระยะแรก', 'ระยะที่สอง', 'เสียชีวิต'];
  late final TextEditingController _dangerLevelController;
  String? _selectedDangerLevel;

  List<String> _diseaseOptions = [];
  bool _loadingDiseases = true;

  late final TextEditingController _name,
      _surname, // <--- [เพิ่ม]
      _disease,
      _sick,
      _start,
      _end,
      _phone,
      _desc,
      _range,
      _houseNo,
      _moo,
      _village,
      _soi,
      _road,
      _sub,
      _dist,
      _prov,
      _post,
      _land;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _name = TextEditingController(text: r.name);
    _surname = TextEditingController(text: r.surname); // <--- [เพิ่ม]
    _disease = TextEditingController(text: r.disease);
    _sick = TextEditingController(text: _fromApiToDisplay(r.sickDate));
    _start = TextEditingController(text: _fromApiToDisplay(r.startDate));
    _end = TextEditingController(text: _fromApiToDisplay(r.endDate));
    _phone = TextEditingController(text: r.phoneNumber);
    _desc = TextEditingController(text: r.description);
    _range = TextEditingController(text: r.dangerRange);

    _selectedDangerLevel = (r.dangerLevel?.isNotEmpty ?? false)
        ? r.dangerLevel
        : _dangerLevelOptions[0];
    _dangerLevelController =
        TextEditingController(text: _selectedDangerLevel);

    _houseNo = TextEditingController(text: r.houseNo ?? '');
    _moo = TextEditingController(text: r.moo ?? '');
    _village = TextEditingController(text: r.village ?? '');
    _soi = TextEditingController(text: r.soi ?? '');
    _road = TextEditingController(text: r.road ?? '');
    _sub = TextEditingController(text: r.subdistrict ?? '');
    _dist = TextEditingController(text: r.district ?? '');
    _prov = TextEditingController(text: r.province ?? '');
    _post = TextEditingController(text: r.postcode ?? '');
    _land = TextEditingController(text: r.landmark ?? '');

    _fetchDiseases();
  }

  @override
  void dispose() {
    _name.dispose();
    _surname.dispose(); // <--- [เพิ่ม]
    _disease.dispose();
    _sick.dispose();
    _start.dispose();
    _end.dispose();
    _phone.dispose();
    _desc.dispose();
    _range.dispose();
    _dangerLevelController.dispose();
    _houseNo.dispose();
    _moo.dispose();
    _village.dispose();
    _soi.dispose();
    _road.dispose();
    _sub.dispose();
    _dist.dispose();
    _prov.dispose();
    _post.dispose();
    _land.dispose();
    super.dispose();
  }

  String _fromApiToDisplay(String? s) {
    final v = (s ?? '').trim();
    if (v.isEmpty || v == '0000-00-00') return '';
    try {
      final dt = _fmtApi.parseStrict(v);
      return _fmtDisplay.format(dt);
    } catch (_) {
      return v;
    }
  }

  String _toApiDate(String input) {
    final s = input.trim();
    if (s.isEmpty) return '';
    DateTime? dt;
    try {
      dt = _fmtDisplay.parseStrict(s);
    } catch (_) {}
    dt ??= () {
      try {
        return _fmtApi.parseStrict(s);
      } catch (_) {
        return null;
      }
    }();
    return dt != null ? _fmtApi.format(dt) : s;
  }

  Future<void> _pick(TextEditingController c) async {
    DateTime init = DateTime.now();
    final t = c.text.trim();
    if (t.isNotEmpty) {
      try {
        init = _fmtDisplay.parseStrict(t);
      } catch (_) {
        try {
          init = _fmtApi.parseStrict(t);
        } catch (_) {}
      }
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: _primary),
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      c.text = _fmtDisplay.format(picked);
      if (_submitted) _formKey.currentState?.validate();
    }
  }

  Future<void> _fetchDiseases() async {
    setState(() => _loadingDiseases = true);
    try {
      final res = await http.get(
        ApiConfig.u('add_data.php', {'mode': 'diseases'}),
      );
      final setNames = <String>{};
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          for (final item in decoded) {
            final v = item is String
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
      }
      if (!mounted) return;
      setState(() {
        _diseaseOptions = setNames.toList()..sort();
        _loadingDiseases = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDiseases = false);
    }
  }

  String? _required(String? v, String label) {
    if (v == null || v.trim().isEmpty) return 'กรุณากรอก$label';
    return null;
  }

  String? _phoneValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'กรุณากรอกเบอร์โทรศัพท์';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9 || digits.length > 11)
      return 'กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง';
    return null;
  }

  String? _postcodeValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'กรุณากรอกรหัสไปรษณีย์';
    final d = v.replaceAll(RegExp(r'\D'), '');
    if (d.length != 5) return 'รหัสไปรษณีย์ 5 หลัก';
    return null;
  }

  String? _numberValidator(String? v, {bool allowEmpty = true}) {
    if ((v == null || v.trim().isEmpty) && allowEmpty) return null;
    final x = double.tryParse(v!.replaceAll(',', '.'));
    if (x == null) return 'รูปแบบตัวเลขไม่ถูกต้อง';
    return null;
  }

  List<String> _collectErrors() {
    final errs = <String>[];
    if (_name.text.trim().isEmpty) errs.add('ชื่อ');
    //if (_surname.text.trim().isEmpty) errs.add('นามสกุล'); // <--- [เพิ่ม]
    if (_disease.text.trim().isEmpty) errs.add('โรคที่ติด');
    if (_start.text.trim().isEmpty) errs.add('วันรับเชื้อ');
    if (_end.text.trim().isEmpty) errs.add('วันสิ้นสุดการควบคุมโรค');
    if (_phone.text.trim().isEmpty) errs.add('เบอร์โทรศัพท์');
    if (_houseNo.text.trim().isEmpty) errs.add('บ้านเลขที่/ชุมชน');
    if (_moo.text.trim().isEmpty) errs.add('หมู่');
    if (_sub.text.trim().isEmpty) errs.add('ตำบล/แขวง');
    if (_dist.text.trim().isEmpty) errs.add('อำเภอ/เขต');
    if (_prov.text.trim().isEmpty) errs.add('จังหวัด');
    if (_post.text.trim().isEmpty) errs.add('รหัสไปรษณีย์');

    final phoneErr = _phoneValidator(_phone.text);
    if (phoneErr != null) errs.add('เบอร์โทรศัพท์: $phoneErr');

    final postErr = _postcodeValidator(_post.text);
    if (postErr != null) errs.add('รหัสไปรษณีย์: $postErr');

    final rangeErr = _numberValidator(_range.text);
    if (rangeErr != null) errs.add('ระยะอันตราย (เมตร): $rangeErr');

    return errs;
  }

  Future<bool?> _confirm(String msg) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยัน'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0E47A1)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'ตกลง',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _alert(String m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'คำเตือน',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(m),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccessDialog({
    String title = 'สำเร็จ',
    String message = 'ดำเนินการเรียบร้อยแล้ว',
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'success',
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, __, ___) {
        final scale = Tween<double>(
          begin: 0.9,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack));
        final opacity = Tween<double>(begin: 0, end: 1).animate(anim);

        return Opacity(
          opacity: opacity.value,
          child: Transform.scale(
            scale: scale.value,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(ctx).size.width * 0.8,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0E47A1), Color(0xFF2F80ED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.45),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 15.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'ตกลง',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 260),
    );
  }

  Widget _label(String text, {bool required = false}) => RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: _primary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          children: required
              ? const [
                  TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
                ]
              : const [],
        ),
      );

  Widget _tf({
    required String label,
    required TextEditingController c,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    IconData? suffixIcon,
    VoidCallback? onSuffix,
    String? suffixText,
    bool required = false,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: _label(label, required: required),
          ),
          TextFormField(
            controller: c,
            readOnly: readOnly,
            validator: validator,
            keyboardType: keyboardType,
            minLines: minLines,
            maxLines: maxLines,
            autovalidateMode: _submitted
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            decoration: InputDecoration(
              hintText: label,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: _primary, width: 2),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              suffixIcon: suffixIcon != null
                  ? IconButton(
                      icon: Icon(suffixIcon, color: _primary),
                      onPressed: onSuffix,
                    )
                  : (suffixText != null
                      ? Padding(
                          padding: const EdgeInsets.only(right: 12, top: 14),
                          child: Text(
                            suffixText,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        )
                      : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _date(
    String label,
    TextEditingController c, {
    bool required = false,
  }) =>
      _tf(
        label: label,
        c: c,
        readOnly: true,
        required: required,
        suffixIcon: Icons.calendar_month,
        onSuffix: () => _pick(c),
        validator: (v) => _required(v, label),
      );

  Widget _diseaseField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: _label('โรคที่ติด', required: true),
          ),
          TextFormField(
            controller: _disease,
            validator: (v) => _required(v, 'โรคที่ติด'),
            autovalidateMode: _submitted
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            readOnly: false,
            decoration: InputDecoration(
              hintText: 'โรคที่ติด',
              filled: true,
              fillColor: Colors.grey[100],
              suffixIcon: _loadingDiseases
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
                        color: _primary,
                      ),
                      onPressed: () async {
                        if (_diseaseOptions.isEmpty) {
                          _alert('ยังไม่มีรายการโรคจากฐานข้อมูล');
                          return;
                        }
                        final selected = await _showDiseasePickerWithSearch();
                        if (selected != null) {
                          setState(() => _disease.text = selected);
                          if (_submitted) _formKey.currentState?.validate();
                        }
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: _primary, width: 2),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dangerField() => _tf(
        label: 'ระดับความอันตราย',
        c: _dangerLevelController,
        readOnly: true,
        suffixIcon: Icons.format_list_bulleted,
        onSuffix: () async {
          final selected = await showDialog<String>(
            context: context,
            builder: (BuildContext dialogContext) {
              return SimpleDialog(
                title: const Text('เลือกระดับความอันตราย'),
                children: _dangerLevelOptions
                    .map(
                      (e) => SimpleDialogOption(
                        onPressed: () => Navigator.pop(dialogContext, e),
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
      );

  Future<String?> _showDiseasePickerWithSearch() async {
    List<String> filtered = List.of(_diseaseOptions);
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setStateSB) => AlertDialog(
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
                        borderSide: const BorderSide(
                          color: _primary,
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
                    onChanged: (q) {
                      final lower = q.toLowerCase();
                      setStateSB(() {
                        filtered = _diseaseOptions
                            .where(
                              (e) => e.toLowerCase().contains(lower),
                            )
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: filtered.isEmpty
                        ? const Center(child: Text('ไม่พบรายการ'))
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final name = filtered[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 1,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                onTap: () => Navigator.pop(
                                  dialogContext,
                                  name,
                                ),
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
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    setState(() => _submitted = true);

    final formOk = _formKey.currentState?.validate() ?? false;
    final errs = _collectErrors();

    if (!formOk || errs.isNotEmpty) {
      _alert(
        'กรุณาแก้ไขข้อมูลต่อไปนี้ให้ถูกต้อง\n\n' +
            errs.map((e) => '• $e').join('\n'),
      );
      return;
    }

    final ok = await _confirm('ยืนยันการบันทึกข้อมูลนี้หรือไม่?');
    if (ok != true) return;

    final body = {
      'pat_id': widget.record.id,
      'pat_name': _name.text.trim(),
      'pat_surname': _surname.text.trim(), // <--- [ส่งค่า]
      'pat_epidemic': _disease.text.trim(),
      'pat_sick_date': _toApiDate(_sick.text),
      'pat_infection_date': _toApiDate(_start.text),
      'pat_recovery_date': _toApiDate(_end.text),
      'pat_phone': _phone.text.trim(),
      'pat_danger_level': _selectedDangerLevel ?? '',
      'pat_description': _desc.text.trim(),
      'pat_danger_range': _range.text.trim(),
      'pat_latitude': widget.record.latitude ?? '',
      'pat_longitude': widget.record.longitude ?? '',
      'pat_address_house_no': _houseNo.text.trim(),
      'pat_address_moo': _moo.text.trim(),
      'pat_address_village': _village.text.trim(),
      'pat_address_soi': _soi.text.trim(),
      'pat_address_road': _road.text.trim(),
      'pat_address_subdistrict': _sub.text.trim(),
      'pat_address_district': _dist.text.trim(),
      'pat_address_province': _prov.text.trim(),
      'pat_address_postcode': _post.text.trim(),
      'pat_address_landmark': _land.text.trim(),
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await http.post(
        ApiConfig.u(_updateEndpoint),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: utf8.encode(jsonEncode(body)),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close progress

      if (res.statusCode == 200) {
        widget.onSaved();
        await _showSuccessDialog(
          title: 'บันทึกเรียบร้อย',
          message: 'ข้อมูลถูกอัปเดตแล้ว',
        );
        if (!mounted) return;
        Navigator.of(context).pop(); // ปิด dialog แก้ไข
      } else {
        _alert('บันทึกล้มเหลว: ${res.statusCode}\n${res.body}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close progress
      _alert('Error: $e');
    }
  }

  Future<void> _delete() async {
    final ok = await _confirm('ต้องการลบข้อมูลนี้หรือไม่?');
    if (ok != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await http.post(
        ApiConfig.u(_deleteEndpoint),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: utf8.encode(jsonEncode({'id': widget.record.id})),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close progress

      if (res.statusCode == 200) {
        widget.onSaved();
        await _showSuccessDialog(
          title: 'ลบเรียบร้อย',
          message: 'รายการถูกลบออกจากระบบแล้ว',
        );
        if (!mounted) return;
        Navigator.of(context).pop(); // ปิด dialog แก้ไข
      } else {
        _alert('ลบไม่สำเร็จ: ${res.statusCode}\n${res.body}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close progress
      _alert('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 1,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        elevation: 10,
        contentPadding: const EdgeInsets.all(20),
        title: const Text(
          'แก้ไขข้อมูล',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _primary,
          ),
        ),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ [ปรับ Layout ชื่อ-นามสกุล คู่กัน]
                Row(
                  children: [
                    Expanded(
                      child: _tf(
                        label: 'ชื่อ',
                        c: _name,
                        validator: (v) => _required(v, 'ชื่อ'),
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _tf(
                        label: 'นามสกุล',
                        c: _surname,
                        //validator: (v) => _required(v, 'นามสกุล'),
                       // required: true,
                      ),
                    ),
                  ],
                ),
                
                _diseaseField(),
                // <--- [เพิ่ม] วันเริ่มป่วย
                _date('วันเริ่มป่วย', _sick),
                // <--- [แก้ชื่อ]
                _date('วันรับเชื้อ', _start, required: true),
                // <--- [แก้ชื่อ]
                _date('วันสิ้นสุดการควบคุมโรค', _end, required: true),
                _tf(
                  label: 'เบอร์โทรศัพท์',
                  c: _phone,
                  validator: _phoneValidator,
                  keyboardType: TextInputType.phone,
                  required: true,
                ),
                _dangerField(),
                _tf(label: 'คำอธิบาย', c: _desc, minLines: 3, maxLines: 5),
                _tf(
                  label: 'ระยะอันตราย (เมตร)',
                  c: _range,
                  validator: (v) => _numberValidator(v),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _label('ที่อยู่'),
                ),
                const SizedBox(height: 6),
                _tf(
                  label: 'บ้านเลขที่/ชุมชน',
                  c: _houseNo,
                  validator: (v) => _required(v, 'บ้านเลขที่/ชุมชน'),
                  required: true,
                ),
                _tf(
                  label: 'หมู่',
                  c: _moo,
                  validator: (v) => _required(v, 'หมู่'),
                  keyboardType: TextInputType.number,
                  required: true,
                ),
                _tf(label: 'หมู่บ้าน/ชุมชน', c: _village),
                Row(
                  children: [
                    Expanded(child: _tf(label: 'ซอย', c: _soi)),
                    const SizedBox(width: 12),
                    Expanded(child: _tf(label: 'ถนน', c: _road)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _tf(
                        label: 'ตำบล/แขวง',
                        c: _sub,
                        validator: (v) => _required(v, 'ตำบล/แขวง'),
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _tf(
                        label: 'อำเภอ/เขต',
                        c: _dist,
                        validator: (v) => _required(v, 'อำเภอ/เขต'),
                        required: true,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _tf(
                        label: 'จังหวัด',
                        c: _prov,
                        validator: (v) => _required(v, 'จังหวัด'),
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _tf(
                        label: 'รหัสไปรษณีย์',
                        c: _post,
                        validator: _postcodeValidator,
                        keyboardType: TextInputType.number,
                        required: true,
                      ),
                    ),
                  ],
                ),
                _tf(label: 'จุดสังเกต', c: _land),
              ],
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: Colors.white,
              foregroundColor: Colors.grey[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: _delete,
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
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
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
}