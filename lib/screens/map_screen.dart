import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> _controller = Completer();

  LatLng? _center;
  final double _circleRadius = 300;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getInitialLocation();
  }

  Future<void> _getInitialLocation() async {
    try {
      await _determinePosition();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permissions are denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permissions are permanently denied.');
      return;
    }

    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _center = LatLng(pos.latitude, pos.longitude);

      if (_controller.isCompleted) {
        final mapCtrl = await _controller.future;
        mapCtrl.animateCamera(CameraUpdate.newLatLng(_center!));
      }
    } catch (e) {
      _showSnackBar('Failed to get your current location.');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _center == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          GoogleMap(
            myLocationEnabled: true,
            initialCameraPosition: CameraPosition(target: _center!, zoom: 15),
            markers: {
              Marker(markerId: const MarkerId('center'), position: _center!),
            },
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
          ),
          _buildTopBar(),
          _buildFloatingButtons(),
          _buildBottomSheet(),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
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
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue.shade900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const CircleAvatar(radius: 35, backgroundColor: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    'ชื่อผู้ใช้',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            _drawerItem(Icons.person, 'โปรไฟล์'),
            _drawerItem(Icons.home, 'หน้าแรก'),
            _drawerItem(Icons.filter_list, 'ตัวกรอง'),
            _drawerItem(Icons.history, 'ประวัติ'),
            _drawerItem(Icons.add_box, 'เพิ่มข้อมูล'),
            _drawerItem(Icons.logout, 'ออกจากระบบ'),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () => Navigator.pop(context),
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
            const SizedBox(width: 16),
            const Expanded(
              child: Text('Search', style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
            const Icon(Icons.search, color: Colors.white),
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
              final controller = await _controller.future;
              controller.animateCamera(CameraUpdate.zoomIn());
            },
            child: const Icon(Icons.center_focus_strong),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            onPressed: () {
              // เพิ่มหมุดในอนาคต
            },
            child: const Icon(Icons.location_pin),
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
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(16),
          children: [
            const Center(child: Icon(Icons.drag_handle, color: Colors.grey)),
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
                Text('มาก', style: TextStyle(fontSize: 16, color: Colors.red)),
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
