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

  final Set<Marker> _patientMarkers = {};
  final Set<Marker> _userMarkers = {};
  final Set<Circle> _dangerCircles = {};

  CameraPosition? _currentCameraPosition;
  double? _lastMarkerLat;
  double? _lastMarkerLng;
  String _bottomSheetTitle = 'ไม่พบข้อมูล';
  String _bottomSheetDanger = 'ไม่พบข้อมูล';
  String _bottomSheetDescription = 'ไม่พบข้อมูล';
  String _bottomSheetDisease = 'ไม่พบข้อมูล';

  bool _isBottomSheetVisible = false;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _getInitialLocation().then((_) {
      if (_center != null) {
        _fetchPatientData();
      }
    });
  }

  Future<void> _fetchUserData() async {
    if (userId == null) return;
    try {
      final response = await http.get(
        Uri.parse("http://10.0.2.2/api/get_user.php?id=$userId"),
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
        _addMarkersAndCirclesFromData(data);
      } else {
        debugPrint("❌ Failed to fetch patient data: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error fetching patient data: $e");
    }
  }

  void _addMarkersAndCirclesFromData(List<dynamic> patientData) {
    setState(() {
      _patientMarkers.clear();
      _dangerCircles.clear();
    });

    for (var patient in patientData) {
      try {
        final double lat =
            double.tryParse(patient['latitude']?.toString() ?? '') ?? 0.0;
        final double lng =
            double.tryParse(patient['longitude']?.toString() ?? '') ?? 0.0;
        final String name = patient['name']?.toString() ?? 'ไม่ระบุ';
        final String danger = patient['danger_level']?.toString() ?? 'ไม่ระบุ';
        final String description = patient['description']?.toString() ?? 'ไม่มีคำอธิบาย';
        final double dangerRange = double.tryParse(patient['danger_range']?.toString() ?? '0') ?? 0;
        final String infectedDisease = patient['disease']?.toString() ?? 'ไม่ระบุ';

        final String markerIdVal = 'patient_${patient['id']}';
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
            _updateBottomSheet(name, danger, description, infectedDisease);
          },
        );
        setState(() {
          _patientMarkers.add(newMarker);
        });

        final Circle newCircle = Circle(
          circleId: CircleId('danger_zone_${patient['id']}'),
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
  ) {
    setState(() {
      _bottomSheetTitle = name;
      _bottomSheetDanger = danger;
      _bottomSheetDescription = description;
      _bottomSheetDisease = disease;
      _isBottomSheetVisible = true;
    });
  }

  void _hideBottomSheet() {
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
          _center = const LatLng(18.7883, 98.9853);
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
            _center = const LatLng(18.7883, 98.9853);
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
          _center = const LatLng(18.7883, 98.9853);
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
          _center = const LatLng(18.7883, 98.9853);
          _addDefaultMarker(_center!);
        });
      }
    }
  }

  void _addDefaultMarker(LatLng latLng) {
    setState(() {
      _hideBottomSheet();
      final markerId = const MarkerId('current_location');
      _userMarkers.removeWhere((m) => m.markerId == markerId);
      _userMarkers.add(
        Marker(
          markerId: markerId,
          position: latLng,
          icon: BitmapDescriptor.defaultMarker,
          onTap: _hideBottomSheet, // เพิ่มคำสั่งนี้เพื่อซ่อน Bottom Sheet
        ),
      );
    });
  }

  void _addMarker(LatLng latLng) {
    setState(() {
      _userMarkers.clear();
      _isBottomSheetVisible = false; // ซ่อน Bottom Sheet เมื่อสร้างมาร์กเกอร์ใหม่
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
      onTap: _hideBottomSheet, // เพิ่มคำสั่งนี้เพื่อซ่อน Bottom Sheet
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
                              (userData != null && userData!['avatar'] != null)
                                  ? NetworkImage(
                                      "http://10.0.2.2/api/${userData!['avatar']}",
                                    )
                                  : null,
                          child:
                              (userData == null || userData!['avatar'] == null)
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
                              ? "${userData!['f_name']} ${userData!['l_name']}"
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
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FilterScreen()),
                );
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
    TextEditingController _searchController = TextEditingController();
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
                const Text('7d3hr19m28s'),
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