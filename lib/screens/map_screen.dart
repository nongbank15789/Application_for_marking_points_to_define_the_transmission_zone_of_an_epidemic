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

  final double _circleRadius = 300;

  bool _isLoading = true;

  // Set to hold all markers on the map

  final Set<Marker> _markers = {};

  CameraPosition? _currentCameraPosition; // เพิ่มตัวแปรนี้

  @override
  void initState() {
    super.initState();

    _loadUserId();

    _getInitialLocation();
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
          _markers.clear();
          _markers.add(
            Marker(
              markerId: const MarkerId("search_location"),
              position: target,
              infoWindow: InfoWindow(title: query),
            ),
          );
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

  // Function to add a single default marker (e.g., current location)

  void _addDefaultMarker(LatLng latLng) {
    final markerId = const MarkerId('current_location');

    _markers.removeWhere((m) => m.markerId == markerId); // ลบ Marker เก่า
    _markers.add(
      Marker(
        markerId: markerId,
        position: latLng,
        icon: BitmapDescriptor.defaultMarker,
      ),
    );
  }

  // Function to add a marker on a long press

  void _addMarker(LatLng latLng) {
    // ลบมาร์กเกอร์เดิมออกทั้งหมดก่อน
    setState(() {
      _markers.clear();
    });

    final String markerIdVal = 'marker_${_markers.length}';
    final MarkerId markerId = MarkerId(markerIdVal);

    final Marker newMarker = Marker(
      markerId: markerId,
      position: latLng,
      infoWindow: InfoWindow(
        title: 'ลบมาร์คเกอร์',
        snippet: 'Lat: ${latLng.latitude}, Lng: ${latLng.longitude}',
        onTap: () {
          _showMarkerDetailsDialog(markerId);
        },
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    setState(() {
      _markers.add(newMarker);
    });

    // ✅ เก็บค่าพิกัดเพื่อใช้งานต่อ
    double markerLat = latLng.latitude;
    double markerLng = latLng.longitude;

    debugPrint('Marker added at: Lat=$markerLat, Lng=$markerLng');

    // ถ้าต้องการเก็บในตัวแปร class
    _lastMarkerLat = markerLat;
    _lastMarkerLng = markerLng;

    // หรือส่งไป API
    //_sendMarkerToApi(markerLat, markerLng);
  }

  // ตัวแปรเก็บค่า
  double? _lastMarkerLat;
  double? _lastMarkerLng;

  // New function to show a dialog with a delete option

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

  // Function to remove a specific marker

  void _removeMarker(MarkerId markerId) {
    setState(() {
      _markers.removeWhere((marker) => marker.markerId == markerId);
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
            markers: _markers,
            compassEnabled: false,
            circles: {
              Circle(
                circleId: const CircleId('danger_zone'),
                center: _center!,
                radius: _circleRadius,
                fillColor: Colors.red.withOpacity(0.2),
                strokeColor: Colors.red.withOpacity(0.5),
                strokeWidth: 2,
              ),
            },
            onMapCreated: (controller) {
              _controller.complete(controller);
            },
            onLongPress: _addMarker,
            onCameraMove: (position) {
              _currentCameraPosition = position; // อัปเดตตำแหน่งกล้อง
            },
          ),
          _buildTopBar(),
          _buildFloatingButtons(),
          _buildBottomSheet(),
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
                // ตรวจสอบว่ามี Marker ล่าสุดหรือไม่
                if (_lastMarkerLat != null && _lastMarkerLng != null) {
                  Navigator.pop(context);
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
                } else if (_center != null) {
                  // ถ้าไม่มี Marker ให้ใช้ตำแหน่งปัจจุบัน
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => AddDataScreen(
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

            // ✅ TextField แทน Text
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
            onPressed: _determinePosition,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            onPressed: () async {
              if (_controller.isCompleted) {
                final controller = await _controller.future;
                controller.animateCamera(CameraUpdate.zoomIn());
              }
            },
            child: const Icon(Icons.center_focus_strong),
          ),
          const SizedBox(height: 8),
          // ปุ่มเข็มทิศ
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
                      bearing: 0, // หมุนกล้องไปทิศเหนือ
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
                  children: const [
                    Icon(Icons.location_on, color: Colors.red),

                    SizedBox(width: 8),

                    Text('ไข้เลือดออก', style: TextStyle(fontSize: 18)),

                    Spacer(),

                    Text('7d3hr19m28s'),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: const [
                    Text('ระดับความอันตราย: ', style: TextStyle(fontSize: 16)),

                    Text(
                      'มาก',

                      style: TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                const TextField(
                  maxLines: 4,

                  decoration: InputDecoration(
                    border: OutlineInputBorder(),

                    labelText: 'คำอธิบาย',
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
