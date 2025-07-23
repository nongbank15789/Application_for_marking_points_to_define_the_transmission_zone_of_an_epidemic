import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  LatLng _center = const LatLng(18.7883, 98.9853); // กำหนดค่าเริ่มต้นเป็นเชียงใหม่
  final double _circleRadius = 300;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // ตรวจสอบว่าบริการระบุตำแหน่งเปิดใช้งานอยู่หรือไม่
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // บริการระบุตำแหน่งปิดอยู่ ไม่สามารถเข้าถึงตำแหน่งได้
      _showSnackBar('Location services are disabled. Please enable them.');
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // สิทธิ์การเข้าถึงตำแหน่งถูกปฏิเสธ สามารถลองขอใหม่ได้ในครั้งหน้า
        _showSnackBar('Location permissions are denied. Cannot show your location.');
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // สิทธิ์การเข้าถึงตำแหน่งถูกปฏิเสธอย่างถาวร จัดการตามความเหมาะสม
      _showSnackBar('Location permissions are permanently denied, we cannot request permissions.');
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // เมื่อมาถึงตรงนี้ แสดงว่าได้รับสิทธิ์แล้ว และสามารถเข้าถึงตำแหน่งของอุปกรณ์ได้
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high, // ขอความแม่นยำสูง
      );
      setState(() {
        _center = LatLng(pos.latitude, pos.longitude);
        // เลื่อนกล้องไปยังตำแหน่งปัจจุบัน (เป็นตัวเลือกเสริม)
        _mapController.animateCamera(CameraUpdate.newLatLng(_center));
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
      _showSnackBar('Failed to get your current location.');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) { // ตรวจสอบว่า Widget ยังอยู่ใน Widget tree ก่อนแสดง SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
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
            children: <Widget>[
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blue.shade900,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ชื่อผู้ใช้',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.white),
                title: const Text('โปรไฟล์', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.home, color: Colors.white),
                title: const Text('หน้าแรก', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.filter_list, color: Colors.white),
                title: const Text('ตัวกรอง', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.white),
                title: const Text('ประวัติ', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_box, color: Colors.white),
                title: const Text('เพิ่มข้อมูล', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white),
                title: const Text('ออกจากระบบ', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            myLocationEnabled: true,
            initialCameraPosition: CameraPosition(target: _center, zoom: 15),
            markers: {
              Marker(markerId: const MarkerId('center'), position: _center),
            },
            circles: {
              Circle(
                circleId: const CircleId('danger_zone'),
                center: _center,
                radius: _circleRadius,
                fillColor: Colors.red.withOpacity(0.2),
                strokeColor: Colors.red.withOpacity(0.5),
                strokeWidth: 2,
              ),
            },
            onMapCreated: (controller) => _mapController = controller,
          ),
          Positioned(
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
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Search',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  const Icon(Icons.search, color: Colors.white),
                ],
              ),
            ),
          ),
          Positioned(
            top: 110,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  onPressed: () async {
                    // จัดแผนที่ให้อยู่กึ่งกลางตำแหน่งปัจจุบัน
                    await _determinePosition();
                  },
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    // ตัวอย่าง: ซูมเข้า/ออก หรือควบคุมแผนที่อื่นๆ
                    _mapController.animateCamera(CameraUpdate.zoomIn());
                  },
                  child: const Icon(Icons.center_focus_strong),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    // ตัวอย่าง: เพิ่มหมุดที่กึ่งกลางของแผนที่
                  },
                  child: const Icon(Icons.location_pin),
                ),
              ],
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.2,
            maxChildSize: 0.6,
            builder: (context, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
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
                      Text(
                        'ระดับความอันตราย: ',
                        style: TextStyle(fontSize: 16),
                      ),
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
          ),
        ],
      ),
    );
  }
}