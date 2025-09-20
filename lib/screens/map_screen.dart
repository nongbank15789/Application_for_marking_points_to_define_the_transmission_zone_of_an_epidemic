import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:project/screens/auth_screen.dart';
import 'drawer_list_item.dart';
import 'profile_screen.dart';
import 'filter_screen.dart';
import 'history_screen.dart';
import 'add_data_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MapScreen extends StatefulWidget {
  final int? userId;
  final double? latitude;
  final double? longitude;
  final bool markMode; // โหมดมาร์กตำแหน่ง

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
  bool get _confirmBarVisible =>
      widget.markMode && _lastMarkerLat != null && _lastMarkerLng != null;
  final _secure = const FlutterSecureStorage();

  List<dynamic> _allPatients = [];
  final Set<Marker> _patientMarkers = {};
  final Set<Marker> _userMarkers = {};
  final Set<Circle> _dangerCircles = {};

  Map<String, dynamic> _activeFilters = {
    'infectedDate': 'ทั้งหมด',
    'recoveryDate': 'ทั้งหมด',
    'disease': 'ทั้งหมด',
    'danger': 'ทั้งหมด',
  };

  // ซ่อน InfoWindow ของ "มาร์กผู้ป่วย" ขณะมีปุ่มยืนยันด้านล่าง
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
  String _countdownString = '0d 0h 0m 0s';
  Timer? _timer;

  late final TextEditingController _searchController;

  // Tip banner state (ล่าง)
  bool _showMarkTip = false;
  double _tipOpacity = 0.0;
  Timer? _tipTimer;

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

    // แสดงทิปเมื่อเข้าโหมด mark
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.markMode) {
        _showMarkTip = true;
        setState(() => _tipOpacity = 1.0);
        _tipTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) setState(() => _tipOpacity = 0.0);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tipTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    if (userId == null) return;
    try {
      final response = await http.get(
        Uri.parse("http://10.0.2.2/api/get_user.php?stf_id=$userId"),
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
      final response = await http.get(
        Uri.parse("http://10.0.2.2/api/get_all_patients.php"),
      );

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

  void _applyFilters() {
    final filteredPatients =
        _allPatients.where((patient) {
          final isDiseaseMatch =
              _activeFilters['disease'] == 'ทั้งหมด' ||
              (patient['pat_epidemic']?.toString() ?? '') ==
                  _activeFilters['disease'];

          final isDangerMatch =
              _activeFilters['danger'] == 'ทั้งหมด' ||
              (patient['pat_danger_level']?.toString() ?? '') ==
                  _activeFilters['danger'];

          bool isInfectionDateMatch = true;
          if (_activeFilters['infectedDate'] != 'ทั้งหมด') {
            final infectedDateString =
                patient['pat_infection_date']?.toString();
            if (infectedDateString != null && infectedDateString.isNotEmpty) {
              final infectedDate = DateTime.tryParse(infectedDateString);
              if (infectedDate != null) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final patientDate = DateTime(
                  infectedDate.year,
                  infectedDate.month,
                  infectedDate.day,
                );

                switch (_activeFilters['infectedDate']) {
                  case 'วันนี้':
                    isInfectionDateMatch = patientDate.isAtSameMomentAs(today);
                    break;
                  case 'สัปดาห์นี้':
                    final startOfWeek = today.subtract(
                      Duration(days: today.weekday - 1),
                    );
                    final endOfWeek = startOfWeek.add(const Duration(days: 7));
                    isInfectionDateMatch =
                        (patientDate.isAfter(startOfWeek) &&
                            patientDate.isBefore(endOfWeek)) ||
                        patientDate.isAtSameMomentAs(startOfWeek);
                    break;
                  case 'เดือนนี้':
                    final startOfMonth = DateTime(now.year, now.month, 1);
                    final endOfMonth = DateTime(now.year, now.month + 1, 1);
                    isInfectionDateMatch =
                        (patientDate.isAfter(startOfMonth) &&
                            patientDate.isBefore(endOfMonth)) ||
                        patientDate.isAtSameMomentAs(startOfMonth);
                    break;
                  case 'ปีนี้':
                    final startOfYear = DateTime(now.year, 1, 1);
                    final endOfYear = DateTime(now.year + 1, 1, 1);
                    isInfectionDateMatch =
                        (patientDate.isAfter(startOfYear) &&
                            patientDate.isBefore(endOfYear)) ||
                        patientDate.isAtSameMomentAs(startOfYear);
                    break;
                }
              }
            }
          }

          bool isRecoveryDateMatch = true;
          if (_activeFilters['recoveryDate'] != 'ทั้งหมด') {
            final recoveryDateString = patient['pat_recovery_date']?.toString();
            if (recoveryDateString != null && recoveryDateString.isNotEmpty) {
              final recoveryDate = DateTime.tryParse(recoveryDateString);
              if (recoveryDate != null) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final patientDate = DateTime(
                  recoveryDate.year,
                  recoveryDate.month,
                  recoveryDate.day,
                );

                switch (_activeFilters['recoveryDate']) {
                  case 'วันนี้':
                    isRecoveryDateMatch = patientDate.isAtSameMomentAs(today);
                    break;
                  case 'สัปดาห์นี้':
                    final startOfWeek = today.subtract(
                      Duration(days: today.weekday - 1),
                    );
                    final endOfWeek = startOfWeek.add(const Duration(days: 7));
                    isRecoveryDateMatch =
                        (patientDate.isAfter(startOfWeek) &&
                            patientDate.isBefore(endOfWeek)) ||
                        patientDate.isAtSameMomentAs(startOfWeek);
                    break;
                  case 'เดือนนี้':
                    final startOfMonth = DateTime(now.year, now.month, 1);
                    final endOfMonth = DateTime(now.year, now.month + 1, 1);
                    isRecoveryDateMatch =
                        (patientDate.isAfter(startOfMonth) &&
                            patientDate.isBefore(endOfMonth)) ||
                        patientDate.isAtSameMomentAs(startOfMonth);
                    break;
                  case 'ปีนี้':
                    final startOfYear = DateTime(now.year, 1, 1);
                    final endOfYear = DateTime(now.year + 1, 1, 1);
                    isRecoveryDateMatch =
                        (patientDate.isAfter(startOfYear) &&
                            patientDate.isBefore(endOfYear)) ||
                        patientDate.isAtSameMomentAs(startOfYear);
                    break;
                }
              }
            }
          }

          final recovered = _isRecovered(
            patient['pat_recovery_date']?.toString(),
          );

          return isDiseaseMatch &&
              isDangerMatch &&
              isInfectionDateMatch &&
              isRecoveryDateMatch &&
              !recovered;
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
        if (_isRecovered(patient['pat_recovery_date']?.toString())) continue;

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

        final double hueColor;
        Color circleColor;
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
            circleColor = Colors.yellow.shade700;
            break;
          default:
            hueColor = BitmapDescriptor.hueBlue;
            circleColor = Colors.blue;
        }

        final Marker newMarker = Marker(
          markerId: MarkerId('patient_$patId'),
          position: LatLng(lat, lng),
          // แสดง/ซ่อน InfoWindow ของ "ผู้ป่วย" ตามสถานะ
          infoWindow:
              _suppressInfoWindows
                  ? const InfoWindow() // ไม่มี title/snippet = ไม่แสดง InfoWindow
                  : InfoWindow(
                    title: 'ผู้ป่วย: $name',
                    snippet: 'ระดับความอันตราย: $danger\nโรค: $infectedDisease',
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

        final Circle newCircle = Circle(
          circleId: CircleId('danger_zone_$patId'),
          center: LatLng(lat, lng),
          radius: dangerRange,
          fillColor: circleColor.withOpacity(0.2),
          strokeColor: circleColor.withOpacity(0.5),
          strokeWidth: 2,
        );

        setState(() {
          _patientMarkers.add(newMarker);
          _dangerCircles.add(newCircle);
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
    // ถ้ามีปุ่มยืนยันตำแหน่งอยู่ ไม่ให้แผงข้อมูลขึ้นมา
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
      _startCountdown(recoveryDate);
    } else {
      setState(() => _countdownString = 'ไม่ระบุวันที่หาย');
    }
  }

  void _startCountdown(String recoveryDate) {
    try {
      final recoveryDateTime = DateTime.parse(recoveryDate);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final remainingTime = recoveryDateTime.difference(DateTime.now());
        if (remainingTime.isNegative) {
          timer.cancel();
          setState(() {
            _countdownString = 'หายแล้ว';
            if (_selectedPatientId != null) {
              _patientMarkers.removeWhere(
                (m) => m.markerId.value == 'patient_${_selectedPatientId!}',
              );
              _dangerCircles.removeWhere(
                (c) => c.circleId.value == 'danger_zone_${_selectedPatientId!}',
              );
            }
            _isBottomSheetVisible = false;
          });
        } else {
          final days = remainingTime.inDays;
          final hours = remainingTime.inHours % 24;
          final minutes = remainingTime.inMinutes % 60;
          final seconds = remainingTime.inSeconds % 60;
          setState(() {
            _countdownString = '${days}d ${hours}h ${minutes}m ${seconds}s';
          });
        }
      });
    } catch (e) {
      debugPrint("❌ Error parsing recovery date: $e");
      setState(() {
        _countdownString = 'ไม่ระบุวันที่หาย';
      });
    }
  }

  void _hideBottomSheet() {
    _timer?.cancel();
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

  // ===== Logout แบบชัวร์
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
    _center ??= const LatLng(13.7563, 100.5018); // Bangkok fallback
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
      _suppressInfoWindows = true; // ซ่อน info ผู้ป่วยตอนมีปุ่มยืนยัน
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
      _suppressInfoWindows = false; // กลับมาแสดง InfoWindow ผู้ป่วยตามปกติ
    });
    _applyFilters(); // รีเฟรชมาร์กผู้ป่วย (สำหรับ InfoWindow)
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

  // ===== Tip แบนเนอร์ด้านล่าง (แสดงเมื่อ markMode = true) =====
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

        // <- สำคัญ: เมื่อ opacity = 0 ให้เลิก intercept การกด
        child: IgnorePointer(
          ignoring: _tipOpacity == 0,

          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _tipOpacity,
            // ถ้าอยากให้หายไปจาก tree เลยหลังจาง ให้ย้าย _showMarkTip=false ที่ onEnd
            onEnd: () {
              if (_tipOpacity == 0 && mounted) {
                setState(() => _showMarkTip = false); // (ทางเลือก)
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

  // ===== แถบปุ่มยืนยันด้านล่าง (มี "ลบมาร์ก" + "ยืนยันตำแหน่ง") =====
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
            // ---- ลบมาร์ก ----
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                clipBehavior:
                    Clip.hardEdge, // สำคัญ: ให้ hit test ถูกตัดตามโค้ง
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('ลบมาร์ก'),
                  style: OutlinedButton.styleFrom(
                    // ให้ขนาดกดเท่าปุ่มจริง
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size.fromHeight(
                      0,
                    ), // ไม่บังคับขนาดเกินจำเป็น
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: _clearUserMarker,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ---- ยืนยันตำแหน่ง ----
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
              _addMarker(pos); // แตะค้างเพื่อวางมาร์ก
            },
            onTap: (_) {
              if (_isBottomSheetVisible) _hideBottomSheet();
            },
            onCameraMove: (position) {
              _currentCameraPosition = position;
            },
          ),
          _buildTopBar(),
          _buildFloatingButtons(),
          if (_isBottomSheetVisible && !_confirmBarVisible) _buildBottomSheet(),

          // ลำดับ: ปุ่มยืนยัน/ลบ (ล่างสุด) แล้วค่อยทิป
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
                                  "http://10.0.2.2/api/${userData!['stf_avatar']}",
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
                    _activeFilters = selectedFilters;
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
                    builder: (context) => const HistoryScreen(),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.menu,
                        color: Colors.white,
                        size: 26,
                      ),
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
                                  hintText: 'Search',
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
                      icon: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () {
                        final q = _searchController.text.trim();
                        if (q.isNotEmpty) _searchLocation(q);
                        _searchController.clear();
                      },
                    ),
                  ],
                );
              },
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
      initialChildSize: 0.3,
      minChildSize: 0.2,
      maxChildSize: 0.6,
      builder:
          (context, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              children: [
                const Center(
                  child: Icon(Icons.drag_handle, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      _bottomSheetTitle,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const Spacer(),
                    Text(_countdownString),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'ระดับความอันตราย: ',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      _bottomSheetDanger,
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('โรค: ', style: TextStyle(fontSize: 16)),
                    Text(
                      _bottomSheetDisease,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  maxLines: 4,
                  controller: TextEditingController(
                    text: _bottomSheetDescription,
                  ),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'คำอธิบาย',
                  ),
                  readOnly: true,
                ),
              ],
            ),
          ),
    );
  }
}
