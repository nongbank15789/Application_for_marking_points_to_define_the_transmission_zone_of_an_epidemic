import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:project/screens/auth_screen.dart';
import 'package:project/screens/config.dart';
import 'drawer_list_item.dart';
import 'profile_screen.dart';
import 'filter_screen.dart';
import 'infected_history_screen.dart';
import 'recovered_history_screen.dart';
import 'add_data_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MapScreen extends StatefulWidget {
  final int? userId;
  final double? latitude;
  final double? longitude;
  final bool markMode;

  const MapScreen({
    super.key,
    this.userId,
    this.latitude,
    this.longitude,
    this.markMode = false,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> _controller = Completer();
  bool _usedInitialTarget = false;
  Map<String, dynamic>? userData;
  int? userId;
  LatLng? _center;
  bool _isLoading = true;
  bool _showInfected = true; // ค่าเริ่มต้นให้โชว์ผู้ป่วยติดเชื้อ
  bool _showRecovered = true;

  bool get _confirmBarVisible =>
      widget.markMode && _lastMarkerLat != null && _lastMarkerLng != null;

  final _secure = const FlutterSecureStorage();

  List<dynamic> _allPatients = [];
  final Set<Marker> _patientMarkers = {};
  final Set<Marker> _userMarkers = {};
  final Set<Circle> _dangerCircles = {};

  /// ====== ฟิลเตอร์แบบใหม่: รองรับช่วงวันที่จาก FilterScreen ======
  Map<String, dynamic> _activeFilters = {
    // แสดงผลเฉย ๆ (อาจมีข้อความ “เลือกช่วงวันที่” หรือ “ทั้งหมด”)
    'infectedDate': 'ทั้งหมด',
    'recoveryDate': 'ทั้งหมด',

    // ใช้งานจริงในการกรอง (yyyy-MM-dd หรือ null)
    'infectedStart': null,
    'infectedEnd': null,
    'recoveryStart': null,
    'recoveryEnd': null,

    // ฟิลเตอร์อื่น ๆ
    'disease': 'ทั้งหมด',
    'danger': 'ทั้งหมด',
  };

  bool _suppressInfoWindows = false;

  CameraPosition? _currentCameraPosition;
  double? _lastMarkerLat;
  double? _lastMarkerLng;

  String _bottomSheetTitle = 'ไม่พบข้อมูล';
  String _bottomSheetDanger = 'ไม่พบข้อมูล';
  String _bottomSheetDescription = 'ไม่พบข้อมูล';
  String _bottomSheetDisease = 'ไม่พบข้อมูล';
  int? _selectedPatientId;

  bool _isBottomSheetVisible = false;
  final ValueNotifier<String> _countdownVN = ValueNotifier<String>(
    '0d 0h 0m 0s',
  );
  Timer? _timer;

  Timer? _autoRefreshTimer;
  Timer? _refetchTimer;

  late final TextEditingController _searchController;

  bool _showMarkTip = false;
  double _tipOpacity = 0.0;
  Timer? _tipTimer;

  // bottom sheet dynamic size
  final GlobalKey _sheetContentKey = GlobalKey();
  double _sheetMinSize = 0.20;
  double _sheetMaxSize = 0.60;
  double _sheetInitialSize = 0.30;
  double _lastMeasuredHeight = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadUserId();
    _getInitialLocation().then((_) {
      if (_center != null) {
        _fetchPatientData();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.markMode) {
        _showMarkTip = true;
        setState(() => _tipOpacity = 1.0);
        _tipTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) setState(() => _tipOpacity = 0.0);
        });
      }
    });

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _applyFilters();
    });

    _refetchTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      if (!mounted) return;
      await _fetchPatientData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tipTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _refetchTimer?.cancel();
    _searchController.dispose();
    _countdownVN.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    if (userId == null) return;
    try {
      final response = await http.get(
        ApiConfig.u('get_user.php', {'stf_id': userId.toString()}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          setState(() {
            userData = data[0];
          });
        }
      } else {
        debugPrint("❌ Failed to fetch user data: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error fetching user data: $e");
    }
  }

  Future<void> _fetchPatientData() async {
    try {
      final response = await http.get(ApiConfig.u("/get_all_patients.php"));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _allPatients = data;
        });
        _applyFilters();
      } else {
        debugPrint("❌ Failed to fetch patient data: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error fetching patient data: $e");
    }
  }

  bool _isRecovered(String? recoveryDateStr) {
    if (recoveryDateStr == null) return false;
    final s = recoveryDateStr.trim();
    if (s.isEmpty) return false;

    DateTime? dt = DateTime.tryParse(s);
    if (dt == null) return false;

    if (s.length == 10) {
      dt = DateTime(dt.year, dt.month, dt.day, 0, 0, 0);
    }
    final now = DateTime.now();
    return now.isAfter(dt) || now.isAtSameMomentAs(dt);
  }

  /// ---------- Helper: parse yyyy-MM-dd (หรือแบบเต็ม) เป็น DateTime (ตัดเวลา) ----------
  DateTime? _parseYmdToDate(String? s) {
    if (s == null) return null;
    final t = s.trim();
    if (t.isEmpty) return null;
    final dt = DateTime.tryParse(t);
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// ---------- กรองข้อมูลด้วยฟิลเตอร์ใหม่ ----------
  void _applyFilters() {
    final String diseaseFilter =
        (_activeFilters['disease'] ?? 'ทั้งหมด').toString();
    final String dangerFilter =
        (_activeFilters['danger'] ?? 'ทั้งหมด').toString();

    final DateTime? infectedStart = _parseYmdToDate(
      _activeFilters['infectedStart']?.toString(),
    );
    final DateTime? infectedEnd = _parseYmdToDate(
      _activeFilters['infectedEnd']?.toString(),
    );
    final DateTime? recoveryStart = _parseYmdToDate(
      _activeFilters['recoveryStart']?.toString(),
    );
    final DateTime? recoveryEnd = _parseYmdToDate(
      _activeFilters['recoveryEnd']?.toString(),
    );

    final filteredPatients =
        _allPatients.where((patient) {
          final isRecovered = _isRecovered(
            patient['pat_recovery_date']?.toString(),
          );

          // 👇 ปรับเงื่อนไข: แสดงได้ทั้ง 2 ถ้าเลือก
          if (!_showInfected && !isRecovered) return false; // ไม่โชว์ infected
          if (!_showRecovered && isRecovered) return false; // ไม่โชว์ recovered

          final isDiseaseMatch =
              diseaseFilter == 'ทั้งหมด' ||
              (patient['pat_epidemic']?.toString() ?? '') == diseaseFilter;

          final isDangerMatch =
              dangerFilter == 'ทั้งหมด' ||
              (patient['pat_danger_level']?.toString() ?? '') == dangerFilter;

          bool isInfectionDateMatch = true;
          final DateTime? infectedDate = _parseYmdToDate(
            patient['pat_infection_date']?.toString(),
          );
          if (infectedStart != null || infectedEnd != null) {
            if (infectedDate == null) {
              isInfectionDateMatch = false;
            } else {
              if (infectedStart != null &&
                  infectedDate.isBefore(infectedStart)) {
                isInfectionDateMatch = false;
              }
              if (infectedEnd != null && infectedDate.isAfter(infectedEnd)) {
                isInfectionDateMatch = false;
              }
            }
          }

          bool isRecoveryDateMatch = true;
          final DateTime? recDate = _parseYmdToDate(
            patient['pat_recovery_date']?.toString(),
          );
          if (recoveryStart != null || recoveryEnd != null) {
            if (recDate == null) {
              isRecoveryDateMatch = false;
            } else {
              if (recoveryStart != null && recDate.isBefore(recoveryStart)) {
                isRecoveryDateMatch = false;
              }
              if (recoveryEnd != null && recDate.isAfter(recoveryEnd)) {
                isRecoveryDateMatch = false;
              }
            }
          }

          return isDiseaseMatch &&
              isDangerMatch &&
              isInfectionDateMatch &&
              isRecoveryDateMatch;
        }).toList();

    _addMarkersAndCirclesFromData(filteredPatients);
  }

  void _addMarkersAndCirclesFromData(List<dynamic> patientData) {
    setState(() {
      _patientMarkers.clear();
      _dangerCircles.clear();
    });

    for (var patient in patientData) {
      try {
        final int patId =
            int.tryParse(patient['pat_id']?.toString() ?? '') ?? -1;
        if (patId == -1) continue;

        final double lat =
            double.tryParse(patient['pat_latitude']?.toString() ?? '') ?? 0.0;
        final double lng =
            double.tryParse(patient['pat_longitude']?.toString() ?? '') ?? 0.0;
        final String name = patient['pat_name']?.toString() ?? 'ไม่ระบุ';
        final String danger =
            patient['pat_danger_level']?.toString() ?? 'ไม่ระบุ';
        final String description =
            patient['pat_description']?.toString() ?? 'ไม่มีคำอธิบาย';
        final double dangerRange =
            double.tryParse(patient['pat_danger_range']?.toString() ?? '0') ??
            0;
        final String infectedDisease =
            patient['pat_epidemic']?.toString() ?? 'ไม่ระบุ';
        final String recoveryDate =
            patient['pat_recovery_date']?.toString() ?? '';

        final bool recovered = _isRecovered(recoveryDate);

        final double hueColor;
        Color circleColor;
        if (recovered) {
          hueColor = BitmapDescriptor.hueGreen; // ผู้ที่หายแล้ว = เขียว
          circleColor = Colors.transparent; // ไม่แสดงวงกลมอันตราย
        } else {
          switch (danger) {
            case 'มาก':
              hueColor = BitmapDescriptor.hueRed;
              circleColor = Colors.red;
              break;
            case 'ปานกลาง':
              hueColor = BitmapDescriptor.hueOrange;
              circleColor = Colors.orange;
              break;
            case 'น้อย':
              hueColor = BitmapDescriptor.hueYellow;
              circleColor = const Color.fromARGB(255, 230, 251, 45);
              break;
            default:
              hueColor = BitmapDescriptor.hueBlue;
              circleColor = Colors.blue;
          }
        }

        final Marker newMarker = Marker(
          markerId: MarkerId('patient_$patId'),
          position: LatLng(lat, lng),
          infoWindow:
              _suppressInfoWindows
                  ? const InfoWindow()
                  : InfoWindow(
                    title: 'ผู้ป่วย: $name',
                    snippet:
                        recovered
                            ? 'สถานะ: หายแล้ว\nโรค: $infectedDisease'
                            : 'ระดับความอันตราย: $danger\nโรค: $infectedDisease',
                  ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hueColor),
          onTap: () {
            _updateBottomSheet(
              patId,
              name,
              danger,
              description,
              infectedDisease,
              recoveryDate,
            );
          },
        );

        setState(() {
          _patientMarkers.add(newMarker);

          if (!recovered && dangerRange > 0) {
            _dangerCircles.add(
              Circle(
                circleId: CircleId('danger_zone_$patId'),
                center: LatLng(lat, lng),
                radius: dangerRange,
                fillColor: circleColor.withOpacity(0.2),
                strokeColor: circleColor.withOpacity(0.5),
                strokeWidth: 2,
              ),
            );
          }
        });
      } catch (e) {
        debugPrint("❌ Error parsing patient data: $e");
      }
    }
  }

  void _updateBottomSheet(
    int patId,
    String name,
    String danger,
    String description,
    String disease,
    String recoveryDate,
  ) {
    if (_confirmBarVisible) return;

    _timer?.cancel();
    setState(() {
      _selectedPatientId = patId;
      _bottomSheetTitle = name;
      _bottomSheetDanger = danger;
      _bottomSheetDescription = description;
      _bottomSheetDisease = disease;
      _isBottomSheetVisible = true;
    });

    if (recoveryDate.isNotEmpty) {
      if (_isRecovered(recoveryDate)) {
        _countdownVN.value = 'หายแล้ว';
      } else {
        _startCountdown(recoveryDate);
      }
    } else {
      _countdownVN.value = 'ไม่ระบุวันที่หาย';
    }
    _recalcSheetSizesOnce();
  }

  void _startCountdown(String recoveryDate) {
    try {
      final recoveryDateTime = DateTime.parse(recoveryDate);

      if (DateTime.now().isAfter(recoveryDateTime)) {
        _countdownVN.value = 'หายแล้ว';
        return;
      }

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final remainingTime = recoveryDateTime.difference(DateTime.now());
        if (remainingTime.isNegative) {
          timer.cancel();
          _countdownVN.value = 'หายแล้ว';
          if (mounted) _applyFilters();
        } else {
          final days = remainingTime.inDays;
          final hours = remainingTime.inHours % 24;
          final minutes = remainingTime.inMinutes % 60;
          final seconds = remainingTime.inSeconds % 60;
          _countdownVN.value = '${days}d ${hours}h ${minutes}m ${seconds}s';
        }
      });
    } catch (e) {
      debugPrint("❌ Error parsing recovery date: $e");
      _countdownVN.value = 'ไม่ระบุวันที่หาย';
    }
  }

  void _hideBottomSheet() {
    _timer?.cancel();
    _countdownVN.value = '0d 0h 0m 0s';
    setState(() {
      _isBottomSheetVisible = false;
    });
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = widget.userId ?? prefs.getInt('userId');
    });
    _fetchUserData();
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');

      await _secure.delete(key: 'remember_me');
      await _secure.delete(key: 'login_username');
      await _secure.delete(key: 'login_password');
      await _secure.delete(key: 'session_cookie');
    } catch (e) {
      debugPrint('Logout error: $e');
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthScreen(bypassAutoLogin: true),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (route) => false,
    );
  }

  Future<void> _getInitialLocation() async {
    try {
      await _determinePosition();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    try {
      if (query.isEmpty) return;
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final LatLng target = LatLng(loc.latitude, loc.longitude);

        setState(() {
          _userMarkers.clear();
          _hideBottomSheet();
        });

        if (_controller.isCompleted) {
          final controller = await _controller.future;
          controller.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
        }
      } else {
        _showSnackBar("ไม่พบสถานที่");
      }
    } catch (e) {
      _showSnackBar("เกิดข้อผิดพลาด: $e");
    }
  }

  void _safeSetDefaultCenter() {
    _center ??= const LatLng(13.7563, 100.5018);
  }

  Future<void> _determinePosition({bool forceCurrent = false}) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('กรุณาเปิด Location Services');
      if (mounted && _center == null) {
        setState(() {
          _safeSetDefaultCenter();
          _addDefaultMarker(_center!);
        });
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('ไม่ได้รับอนุญาตใช้งานตำแหน่ง');
        if (mounted && _center == null) {
          setState(() {
            _safeSetDefaultCenter();
            _addDefaultMarker(_center!);
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('สิทธิ์ตำแหน่งถูกปฏิเสธแบบถาวร ให้เปิดใน Settings');
      if (mounted && _center == null) {
        setState(() {
          _safeSetDefaultCenter();
          _addDefaultMarker(_center!);
        });
      }
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        if (!forceCurrent &&
            !_usedInitialTarget &&
            widget.latitude != null &&
            widget.longitude != null) {
          _center = LatLng(widget.latitude!, widget.longitude!);
          _usedInitialTarget = true;
        } else {
          _center = LatLng(pos.latitude, pos.longitude);
        }
      });

      if (_controller.isCompleted && _center != null) {
        final mapCtrl = await _controller.future;
        await mapCtrl.animateCamera(CameraUpdate.newLatLng(_center!));
      }
    } catch (e) {
      debugPrint('Failed to get your current location: $e');
      _showSnackBar('ไม่สามารถดึงตำแหน่งปัจจุบันได้');
      if (mounted && _center == null) {
        setState(() {
          _safeSetDefaultCenter();
          _addDefaultMarker(_center!);
        });
      }
    }
  }

  void _addDefaultMarker(LatLng latLng) {
    setState(() {
      _isBottomSheetVisible = false;
      _timer?.cancel();
      const markerId = MarkerId('current_location');
      _userMarkers.removeWhere((m) => m.markerId == markerId);
      _userMarkers.add(
        Marker(
          markerId: markerId,
          position: latLng,
          icon: BitmapDescriptor.defaultMarker,
          onTap: _hideBottomSheet,
        ),
      );
    });
  }

  void _addMarker(LatLng latLng) {
    setState(() {
      _userMarkers.clear();
      _isBottomSheetVisible = false;
      _timer?.cancel();
      _suppressInfoWindows = true;
    });
    final String markerIdVal = 'user_marker_${_userMarkers.length}';
    final MarkerId markerId = MarkerId(markerIdVal);
    final Marker newMarker = Marker(
      markerId: markerId,
      position: latLng,
      infoWindow: InfoWindow(
        title: 'ลบเครื่องหมาย',
        snippet: 'Lat: ${latLng.latitude}, Lng: ${latLng.longitude}',
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: const Text('ยืนยันการลบ'),
                content: const Text('คุณต้องการลบมาร์กนี้หรือไม่?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('ยกเลิก'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _removeMarker(markerId);
                    },
                    child: const Text(
                      'ลบ',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      onTap: _hideBottomSheet,
    );
    setState(() {
      _userMarkers.add(newMarker);
      _lastMarkerLat = latLng.latitude;
      _lastMarkerLng = latLng.longitude;

      if (_showMarkTip) _tipOpacity = 0.0;
    });
    if (_confirmBarVisible && _isBottomSheetVisible) {
      _hideBottomSheet();
    }
  }

  void _clearUserMarker() {
    setState(() {
      _userMarkers.clear();
      _lastMarkerLat = null;
      _lastMarkerLng = null;
      _suppressInfoWindows = false;
    });
    _applyFilters();
  }

  void _removeMarker(MarkerId markerId) {
    setState(() {
      _userMarkers.removeWhere((marker) => marker.markerId == markerId);
    });
    if (_userMarkers.isEmpty) {
      _clearUserMarker();
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _buildBottomTipBanner() {
    if (!_showMarkTip) return const SizedBox.shrink();
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 76 + bottomInset,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 250),
        offset: _tipOpacity > 0 ? Offset.zero : const Offset(0, 0.2),
        child: IgnorePointer(
          ignoring: _tipOpacity == 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _tipOpacity,
            onEnd: () {
              if (_tipOpacity == 0 && mounted) {
                setState(() => _showMarkTip = false);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF0E47A1).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF0E47A1),
                    radius: 18,
                    child: Icon(Icons.add_location_alt, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'โหมดปักหมุด: แตะค้างบนแผนที่เพื่อวางมาร์ก\nจากนั้นกด “ยืนยันตำแหน่ง” ด้านล่าง',
                      style: TextStyle(fontSize: 14, height: 1.3),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _tipOpacity = 0.0),
                    child: const Text('เข้าใจแล้ว'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomConfirmBar() {
    if (!(widget.markMode &&
        _lastMarkerLat != null &&
        _lastMarkerLng != null)) {
      return const SizedBox.shrink();
    }
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12 + bottomInset,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.hardEdge,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('ลบมาร์ก'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size.fromHeight(0),
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: _clearUserMarker,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.hardEdge,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('ยืนยันตำแหน่ง'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size.fromHeight(0),
                    backgroundColor: const Color(0xFF0E47A1),
                    foregroundColor: Colors.white,
                    elevation: 6,
                  ),
                  onPressed: () {
                    Navigator.pop(
                      context,
                      LatLng(_lastMarkerLat!, _lastMarkerLng!),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _recalcSheetSizesOnce() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _sheetContentKey.currentContext;
      final box = ctx?.findRenderObject() as RenderBox?;
      if (box == null) return;

      final h = box.size.height;
      if ((h - _lastMeasuredHeight).abs() < 8) return;
      _lastMeasuredHeight = h;

      final total = MediaQuery.of(context).size.height;
      final desired = (h / total).clamp(0.20, 0.90);

      if ((desired - _sheetMaxSize).abs() < 0.01 &&
          (desired - _sheetInitialSize).abs() < 0.01)
        return;

      setState(() {
        _sheetMaxSize = desired;
        _sheetInitialSize = desired;
        if (_sheetInitialSize < _sheetMinSize) {
          _sheetInitialSize = _sheetMinSize;
        }
      });
    });
  }

  Widget _buildPatientToggle() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 65,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ปุ่ม ผู้ป่วยติดเชื้อ
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showInfected = !_showInfected;
              });
              _applyFilters();
            },
            icon: Icon(
              Icons.sick_outlined,
              size: 18, // ไอคอนเล็กลง
              color: _showInfected ? Colors.white : Colors.black87,
            ),
            label: Text(
              "ผู้ป่วยติดเชื้อ",
              style: TextStyle(
                fontSize: 13, // ลด font ลง
                color: _showInfected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _showInfected ? const Color(0xFF0E47A1) : Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36), // ความสูงลดลง
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color:
                      _showInfected ? const Color(0xFF0E47A1) : Colors.black26,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ปุ่ม ผู้ป่วยหายแล้ว
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showRecovered = !_showRecovered;
              });
              _applyFilters();
            },
            icon: Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: _showRecovered ? Colors.white : Colors.black87,
            ),
            label: Text(
              "ผู้ป่วยหายแล้ว",
              style: TextStyle(
                fontSize: 13,
                color: _showRecovered ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _showRecovered ? const Color(0xFF0E47A1) : Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color:
                      _showRecovered ? const Color(0xFF0E47A1) : Colors.black26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _center == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          GoogleMap(
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            initialCameraPosition: CameraPosition(target: _center!, zoom: 15),
            markers: _patientMarkers.union(_userMarkers),
            circles: _dangerCircles,
            compassEnabled: false,
            onMapCreated: (controller) {
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }
            },
            onLongPress: (pos) {
              _addMarker(pos);
            },
            onTap: (_) {
              if (_isBottomSheetVisible) _hideBottomSheet();
            },
            onCameraMove: (position) {
              _currentCameraPosition = position;
            },
          ),
          _buildTopBar(),
          _buildPatientToggle(),
          _buildFloatingButtons(),
          if (_isBottomSheetVisible && !_confirmBarVisible)
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _buildBottomSheet(),
              ),
            ),
          _buildBottomConfirmBar(),
          if (widget.markMode) _buildBottomTipBanner(),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      width: MediaQuery.of(context).size.width * 0.75,
      child: Container(
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          children: [
            // Profile header
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 36,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFd6eeff),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFb5e4ff),
                        backgroundImage:
                            (userData != null &&
                                    userData!['stf_avatar'] != null)
                                ? NetworkImage(
                                  ApiConfig.url(userData!['stf_avatar']),
                                )
                                : null,
                        child:
                            (userData == null ||
                                    userData!['stf_avatar'] == null ||
                                    userData!['stf_avatar'].toString().isEmpty)
                                ? const Icon(
                                  Icons.person,
                                  size: 32,
                                  color: Color.fromARGB(200, 14, 70, 161),
                                )
                                : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              userData != null
                                  ? "${userData!['stf_username']}"
                                  : "ชื่อผู้ใช้",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0E47A1),
                              ),
                            ),
                            Text(
                              userData != null
                                  ? (userData!['stf_email'] ?? "")
                                  : "example@email.com",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const Divider(
              thickness: 1,
              height: 1,
              indent: 16,
              endIndent: 16,
              color: Color.fromARGB(31, 0, 0, 0),
            ),
            const SizedBox(height: 16),

            DrawerListItem(
              icon: Icons.person_outline,
              title: 'โปรไฟล์',
              onTap: () {
                if (userId != null) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(userId: userId!),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('ไม่พบ userId')));
                }
              },
            ),
            const SizedBox(height: 6),
            DrawerListItem(
              icon: Icons.tune_outlined,
              title: 'ตัวกรองแผนที่',
              onTap: () async {
                final selectedFilters =
                    await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FilterScreen(),
                      ),
                    );
                if (selectedFilters != null) {
                  setState(() {
                    _activeFilters = {
                      // เก็บค่าที่ FilterScreen ส่งมา (รองรับคีย์ใหม่ทั้งหมด)
                      ..._activeFilters,
                      ...selectedFilters,
                    };
                  });
                  _applyFilters();
                }
              },
            ),
            const SizedBox(height: 6),

            DrawerListItem(
              icon: Icons.history_outlined,
              title: 'ประวัติผู้ป่วย',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InfectedHistoryScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),

            DrawerListItem(
              icon: Icons.verified_user_outlined,
              title: 'ผู้ป่วยที่หายแล้ว',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecoveredHistoryScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),

            DrawerListItem(
              icon: Icons.add_box_outlined,
              title: 'เพิ่มข้อมูลผู้ป่วย',
              onTap: () {
                Navigator.pop(context);
                if (_lastMarkerLat != null && _lastMarkerLng != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => AddDataScreen(
                            latitude: _lastMarkerLat!,
                            longitude: _lastMarkerLng!,
                          ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddDataScreen(),
                    ),
                  );
                }
              },
            ),
            const Spacer(),
            DrawerListItem(
              icon: Icons.logout_outlined,
              title: 'ออกจากระบบ',
              onTap: _logout,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final double topInset = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: topInset + 60,
        decoration: const BoxDecoration(
          color: Color(0xFF084cc5),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              offset: Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white, size: 26),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'ค้นหา...',
                              hintStyle: TextStyle(color: Colors.white),
                              border: InputBorder.none,
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (value) {
                              final q = value.trim();
                              if (q.isNotEmpty) _searchLocation(q);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white, size: 26),
                  onPressed: () {
                    final q = _searchController.text.trim();
                    if (q.isNotEmpty) _searchLocation(q);
                    _searchController.clear();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    final double topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topInset + 80,
      right: 16,
      child: Column(
        children: [
          FloatingActionButton(
            mini: true,
            heroTag: "myLocationBtn",
            backgroundColor: Colors.white,
            onPressed: () => _determinePosition(forceCurrent: true),
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            heroTag: "zoomInBtn",
            backgroundColor: Colors.white,
            onPressed: () async {
              if (_controller.isCompleted) {
                final controller = await _controller.future;
                controller.animateCamera(CameraUpdate.zoomIn());
              }
            },
            child: const Icon(Icons.center_focus_strong),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            heroTag: "compassBtn",
            backgroundColor: Colors.white,
            onPressed: () async {
              try {
                if (_controller.isCompleted && _currentCameraPosition != null) {
                  final controller = await _controller.future;
                  controller.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: _currentCameraPosition!.target,
                        zoom: _currentCameraPosition!.zoom,
                        bearing: 0,
                        tilt: _currentCameraPosition!.tilt,
                      ),
                    ),
                  );
                }
              } catch (e) {
                debugPrint("❌ Error resetting compass: $e");
              }
            },
            child: const Icon(Icons.explore),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: _sheetInitialSize,
      minChildSize: _sheetMinSize,
      maxChildSize: _sheetMaxSize,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SingleChildScrollView(
            controller: scrollCtrl,
            child: Padding(
              key: _sheetContentKey,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Icon(Icons.drag_handle, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _bottomSheetTitle,
                          style: const TextStyle(fontSize: 18),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<String>(
                        valueListenable: _countdownVN,
                        builder: (_, txt, __) => Text(txt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'ระดับความอันตราย: ',
                        style: TextStyle(fontSize: 16),
                      ),
                      Flexible(
                        child: Text(
                          _bottomSheetDanger,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('โรค: ', style: TextStyle(fontSize: 16)),
                      Flexible(
                        child: Text(
                          _bottomSheetDisease,
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'คำอธิบาย',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _bottomSheetDescription.isEmpty
                          ? '—'
                          : _bottomSheetDescription,
                      style: const TextStyle(height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
