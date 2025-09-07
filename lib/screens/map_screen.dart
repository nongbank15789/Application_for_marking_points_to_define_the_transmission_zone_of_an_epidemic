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

class MapScreen extends StatefulWidget {
  final int? userId;

  const MapScreen({super.key, this.userId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> _controller = Completer();
  Map<String, dynamic>? userData;
  int? userId;
  LatLng? _center;
  bool _isLoading = true;

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

  CameraPosition? _currentCameraPosition;
  double? _lastMarkerLat;
  double? _lastMarkerLng;
  String _bottomSheetTitle = 'ไม่พบข้อมูล';
  String _bottomSheetDanger = 'ไม่พบข้อมูล';
  String _bottomSheetDescription = 'ไม่พบข้อมูล';
  String _bottomSheetDisease = 'ไม่พบข้อมูล';

  bool _isBottomSheetVisible = false;

  String _countdownString = '0d 0h 0m 0s';
  Timer? _timer;

  late final TextEditingController _searchController;

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
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  void _applyFilters() {
    final filteredPatients = _allPatients.where((patient) {
      final isDiseaseMatch = _activeFilters['disease'] == 'ทั้งหมด' ||
          (patient['pat_epidemic']?.toString() ?? '') == _activeFilters['disease'];

      final isDangerMatch = _activeFilters['danger'] == 'ทั้งหมด' ||
          (patient['pat_danger_level']?.toString() ?? '') == _activeFilters['danger'];
      
      bool isInfectionDateMatch = true;
      if (_activeFilters['infectedDate'] != 'ทั้งหมด') {
        final infectedDateString = patient['pat_infection_date']?.toString();
        if (infectedDateString != null && infectedDateString.isNotEmpty) {
          final infectedDate = DateTime.tryParse(infectedDateString);
          if (infectedDate != null) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final patientDate = DateTime(infectedDate.year, infectedDate.month, infectedDate.day);

            switch (_activeFilters['infectedDate']) {
              case 'วันนี้':
                isInfectionDateMatch = patientDate.isAtSameMomentAs(today);
                break;
              case 'สัปดาห์นี้':
                final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
                final endOfWeek = startOfWeek.add(const Duration(days: 7));
                isInfectionDateMatch = (patientDate.isAfter(startOfWeek) && patientDate.isBefore(endOfWeek)) || patientDate.isAtSameMomentAs(startOfWeek);
                break;
              case 'เดือนนี้':
                final startOfMonth = DateTime(now.year, now.month, 1);
                final endOfMonth = DateTime(now.year, now.month + 1, 1);
                isInfectionDateMatch = (patientDate.isAfter(startOfMonth) && patientDate.isBefore(endOfMonth)) || patientDate.isAtSameMomentAs(startOfMonth);
                break;
              case 'ปีนี้':
                final startOfYear = DateTime(now.year, 1, 1);
                final endOfYear = DateTime(now.year + 1, 1, 1);
                isInfectionDateMatch = (patientDate.isAfter(startOfYear) && patientDate.isBefore(endOfYear)) || patientDate.isAtSameMomentAs(startOfYear);
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
            final patientDate = DateTime(recoveryDate.year, recoveryDate.month, recoveryDate.day);

            switch (_activeFilters['recoveryDate']) {
              case 'วันนี้':
                isRecoveryDateMatch = patientDate.isAtSameMomentAs(today);
                break;
              case 'สัปดาห์นี้':
                final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
                final endOfWeek = startOfWeek.add(const Duration(days: 7));
                isRecoveryDateMatch = (patientDate.isAfter(startOfWeek) && patientDate.isBefore(endOfWeek)) || patientDate.isAtSameMomentAs(startOfWeek);
                break;
              case 'เดือนนี้':
                final startOfMonth = DateTime(now.year, now.month, 1);
                final endOfMonth = DateTime(now.year, now.month + 1, 1);
                isRecoveryDateMatch = (patientDate.isAfter(startOfMonth) && patientDate.isBefore(endOfMonth)) || patientDate.isAtSameMomentAs(startOfMonth);
                break;
              case 'ปีนี้':
                final startOfYear = DateTime(now.year, 1, 1);
                final endOfYear = DateTime(now.year + 1, 1, 1);
                isRecoveryDateMatch = (patientDate.isAfter(startOfYear) && patientDate.isBefore(endOfYear)) || patientDate.isAtSameMomentAs(startOfYear);
                break;
            }
          }
        }
      }

      return isDiseaseMatch && isDangerMatch && isInfectionDateMatch && isRecoveryDateMatch;
    }).toList();

    // TODO: เพิ่มการเรียงลำดับตาม _activeFilters['sortBy']

    _addMarkersAndCirclesFromData(filteredPatients);
  }

  void _addMarkersAndCirclesFromData(List<dynamic> patientData) {
    setState(() {
      _patientMarkers.clear();
      _dangerCircles.clear();
    });

    for (var patient in patientData) {
      try {
        final double lat =
            double.tryParse(patient['pat_latitude']?.toString() ?? '') ?? 0.0;
        final double lng =
            double.tryParse(patient['pat_longitude']?.toString() ?? '') ?? 0.0;
        final String name = patient['pat_name']?.toString() ?? 'ไม่ระบุ';
        final String danger = patient['pat_danger_level']?.toString() ?? 'ไม่ระบุ';
        final String description = patient['pat_description']?.toString() ?? 'ไม่มีคำอธิบาย';
        final double dangerRange = double.tryParse(patient['pat_danger_range']?.toString() ?? '0') ?? 0;
        final String infectedDisease = patient['pat_epidemic']?.toString() ?? 'ไม่ระบุ';
        final String recoveryDate = patient['pat_recovery_date']?.toString() ?? '';

        final String markerIdVal = 'patient_${patient['pat_id']}';
        final MarkerId markerId = MarkerId(markerIdVal);
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
            circleColor = Colors.yellow;
            break;
          default:
            hueColor = BitmapDescriptor.hueBlue;
            circleColor = Colors.blue;
        }

        final Marker newMarker = Marker(
          markerId: markerId,
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: 'ผู้ป่วย: $name',
            snippet:
                'ระดับความอันตราย: $danger\nโรค: $infectedDisease',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hueColor),
          onTap: () {
            _updateBottomSheet(name, danger, description, infectedDisease, recoveryDate);
          },
        );
        setState(() {
          _patientMarkers.add(newMarker);
        });

        final Circle newCircle = Circle(
          circleId: CircleId('danger_zone_${patient['pat_id']}'),
          center: LatLng(lat, lng),
          radius: dangerRange,
          fillColor: circleColor.withOpacity(0.2),
          strokeColor: circleColor.withOpacity(0.5),
          strokeWidth: 2,
        );
        setState(() {
          _dangerCircles.add(newCircle);
        });
      } catch (e) {
        debugPrint("❌ Error parsing patient data: $e");
      }
    }
  }

  void _updateBottomSheet(
    String name,
    String danger,
    String description,
    String disease,
    String recoveryDate,
  ) {
    _timer?.cancel();
    setState(() {
      _bottomSheetTitle = name;
      _bottomSheetDanger = danger;
      _bottomSheetDescription = description;
      _bottomSheetDisease = disease;
      _isBottomSheetVisible = true;
    });

    if (recoveryDate.isNotEmpty) {
      _startCountdown(recoveryDate);
    } else {
      setState(() {
        _countdownString = 'ไม่ระบุวันที่หาย';
      });
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

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled. Please enable them.');
      if (mounted && _center == null) {
        setState(() {
          _addDefaultMarker(_center!);
        });
      }
      return;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar(
          'Location permissions are denied. Cannot show your location.',
        );
        if (mounted && _center == null) {
          setState(() {
            _addDefaultMarker(_center!);
          });
        }
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnackBar(
        'Location permissions are permanently denied. Please enable them from settings.',
      );
      if (mounted && _center == null) {
        setState(() {
          _addDefaultMarker(_center!);
        });
      }
      return;
    }
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _center = LatLng(pos.latitude, pos.longitude);
        });
      }
      if (_controller.isCompleted) {
        final mapCtrl = await _controller.future;
        mapCtrl.animateCamera(CameraUpdate.newLatLng(_center!));
      }
    } catch (e) {
      debugPrint('Failed to get your current location: $e');
      _showSnackBar('Failed to get your current location.');
      if (mounted && _center == null) {
        setState(() {
          _addDefaultMarker(_center!);
        });
      }
    }
  }

  void _addDefaultMarker(LatLng latLng) {
    setState(() {
      _isBottomSheetVisible = false;
      _timer?.cancel();
      final markerId = const MarkerId('current_location');
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
    });
    final String markerIdVal = 'user_marker_${_userMarkers.length}';
    final MarkerId markerId = MarkerId(markerIdVal);
    final Marker newMarker = Marker(
      markerId: markerId,
      position: latLng,
      infoWindow: InfoWindow(
        title: 'จุดที่ทำเครื่องหมาย',
        snippet: 'Lat: ${latLng.latitude}, Lng: ${latLng.longitude}',
        onTap: () {
          _showMarkerDetailsDialog(markerId);
        },
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      onTap: _hideBottomSheet,
    );
    setState(() {
      _userMarkers.add(newMarker);
    });
    double markerLat = latLng.latitude;
    double markerLng = latLng.longitude;
    _lastMarkerLat = markerLat;
    _lastMarkerLng = markerLng;
  }

  void _showMarkerDetailsDialog(MarkerId markerId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('จัดการจุดที่ทำเครื่องหมาย'),
          content: const Text('คุณต้องการลบจุดนี้หรือไม่?'),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('ลบ', style: TextStyle(color: Colors.red)),
              onPressed: () {
                _removeMarker(markerId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _removeMarker(MarkerId markerId) {
    setState(() {
      _userMarkers.removeWhere((marker) => marker.markerId == markerId);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Marker has been removed.')));
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
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
            myLocationEnabled: false,
            initialCameraPosition: CameraPosition(target: _center!, zoom: 15),
            markers: _patientMarkers.union(_userMarkers),
            circles: _dangerCircles,
            compassEnabled: false,
            onMapCreated: (controller) {
              _controller.complete(controller);
            },
            onLongPress: _addMarker,
            onTap: (_) {
              if (_isBottomSheetVisible) {
                _hideBottomSheet();
              }
            },
            onCameraMove: (position) {
              _currentCameraPosition = position;
            },
          ),
          _buildTopBar(),
          _buildFloatingButtons(),
          if (_isBottomSheetVisible) _buildBottomSheet(),
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
        color: Colors.blue.shade800,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                double headerHeight = MediaQuery.of(context).size.height * 0.25;
                final double minContentHeight = 120.0;
                final double minHeaderHeight =
                    MediaQuery.of(context).padding.top + minContentHeight;
                final double maxHeaderHeight =
                    MediaQuery.of(context).size.height * 0.35;
                headerHeight = headerHeight.clamp(
                  minHeaderHeight,
                  maxHeaderHeight,
                );
                return SizedBox(
                  height: headerHeight,
                  child: DrawerHeader(
                    decoration: BoxDecoration(color: Colors.blue.shade900),
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                          ),
                        ),
                        const Spacer(),
                        CircleAvatar(
                          radius: 30,
                          backgroundImage:
                              (userData != null && userData!['stf_avatar'] != null)
                                  ? NetworkImage(
                                      "http://10.0.2.2/api/${userData!['stf_avatar']}",
                                    )
                                  : null,
                          child:
                              (userData == null || userData!['stf_avatar'] == null)
                                  ? const Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.grey,
                                    )
                                  : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          userData != null
                              ? "${userData!['stf_fname']} ${userData!['stf_lname']}"
                              : "ชื่อผู้ใช้",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            DrawerListItem(
              icon: Icons.person,
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
            DrawerListItem(
              icon: Icons.filter_list,
              title: 'ตัวกรองแผนที่',
              onTap: () async {
                final selectedFilters = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(builder: (context) => const FilterScreen()),
                );
                if (selectedFilters != null) {
                  setState(() {
                    _activeFilters = selectedFilters;
                  });
                  _applyFilters();
                }
              },
            ),
            DrawerListItem(
              icon: Icons.history,
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
            DrawerListItem(
              icon: Icons.add_box,
              title: 'เพิ่มข้อมูลผู้ป่วย',
              onTap: () {
                if (_lastMarkerLat != null && _lastMarkerLng != null) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddDataScreen(
                        latitude: _lastMarkerLat!,
                        longitude: _lastMarkerLng!,
                      ),
                    ),
                  );
                } else if (_center != null) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddDataScreen(
                        latitude: _center!.latitude,
                        longitude: _center!.longitude,
                      ),
                    ),
                  );
                } else {
                  _showSnackBar('กำลังโหลดตำแหน่ง กรุณารอสักครู่...');
                }
              },
            ),
            DrawerListItem(
              icon: Icons.logout,
              title: 'ออกจากระบบ',
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder:
                        (context, animation1, animation2) => const AuthScreen(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 40,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: 50,
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: "Search",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    _searchLocation(value);
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {
                final query = _searchController.text.trim();
                if (query.isNotEmpty) {
                  _searchLocation(query);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Positioned(
      top: 110,
      right: 16,
      child: Column(
        children: [
          FloatingActionButton(
            mini: true,
            heroTag: "myLocationBtn",
            onPressed: _determinePosition,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            heroTag: "zoomInBtn",
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