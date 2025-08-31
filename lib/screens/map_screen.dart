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

class MapScreen extends StatefulWidget {
  final int? userId; // เพิ่ม userId
  const MapScreen({super.key, this.userId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> _controller = Completer();

  Map<String, dynamic>? userData;

  int? userId;
  LatLng? _center; // ตำแหน่งกลางแผนที่ อาจจะเป็น null ในตอนแรก
  final double _circleRadius = 300;
  bool _isLoading = true; // สถานะโหลดข้อมูลเริ่มต้น

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
            userData = data[0]; // เก็บข้อมูล user
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

  // ฟังก์ชันสำหรับดึงตำแหน่งเริ่มต้นและจัดการสถานะโหลด
  Future<void> _getInitialLocation() async {
    try {
      await _determinePosition(); // พยายามดึงตำแหน่ง
    } finally {
      // ใช้ mounted เพื่อป้องกัน setState หลังจาก Widget ถูกทำลาย
      if (mounted) {
        setState(
          () => _isLoading = false,
        ); // เมื่อเสร็จสิ้น (ไม่ว่าจะสำเร็จหรือล้มเหลว) ให้หยุดโหลด
      }
    }
  }

  // ฟังก์ชันสำหรับตรวจสอบและขอสิทธิ์ตำแหน่ง รวมถึงดึงตำแหน่งปัจจุบัน
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. ตรวจสอบว่าบริการระบุตำแหน่งเปิดใช้งานอยู่หรือไม่
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled. Please enable them.');
      // หากบริการปิดอยู่ และ _center ยังเป็น null ให้ตั้งค่าเริ่มต้น
      if (mounted && _center == null) {
        setState(() {
          _center = const LatLng(18.7883, 98.9853); // Default to Chiang Mai
        });
      }
      return; // ออกจากฟังก์ชัน
    }

    // 2. ตรวจสอบสถานะสิทธิ์การเข้าถึงตำแหน่ง
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // หากสิทธิ์ถูกปฏิเสธ ให้ขอสิทธิ์
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // หากผู้ใช้ปฏิเสธอีกครั้ง
        _showSnackBar(
          'Location permissions are denied. Cannot show your location.',
        );
        if (mounted && _center == null) {
          setState(() {
            _center = const LatLng(18.7883, 98.9853); // Default to Chiang Mai
          });
        }
        return; // ออกจากฟังก์ชัน
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // หากสิทธิ์ถูกปฏิเสธอย่างถาวร
      _showSnackBar(
        'Location permissions are permanently denied. Please enable them from settings.',
      );
      if (mounted && _center == null) {
        setState(() {
          _center = const LatLng(18.7883, 98.9853); // Default to Chiang Mai
        });
      }
      return; // ออกจากฟังก์ชัน
    }

    // 3. เมื่อมีสิทธิ์และบริการเปิดใช้งานแล้ว ให้ดึงตำแหน่ง
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high, // ขอความแม่นยำสูง
      );
      // อัปเดต _center และเรียก setState
      if (mounted) {
        setState(() {
          _center = LatLng(pos.latitude, pos.longitude);
        });
      }

      // หาก map controller พร้อมแล้ว ให้เลื่อนแผนที่ไปที่ตำแหน่งปัจจุบัน
      if (_controller.isCompleted) {
        final mapCtrl = await _controller.future;
        mapCtrl.animateCamera(CameraUpdate.newLatLng(_center!));
      }
    } catch (e) {
      // หากเกิดข้อผิดพลาดในการดึงตำแหน่ง
      debugPrint('Failed to get your current location: $e');
      _showSnackBar('Failed to get your current location.');
      // หาก _center ยังเป็น null (ไม่เคยได้ตำแหน่งมาก่อน) ให้ตั้งค่าเริ่มต้น
      if (mounted && _center == null) {
        setState(() {
          _center = const LatLng(18.7883, 98.9853); // Default to Chiang Mai
        });
      }
    }
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
    // แสดง CircularProgressIndicator ขณะโหลดตำแหน่งเริ่มต้น
    if (_isLoading || _center == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey, // กำหนด GlobalKey ให้ Scaffold เพื่อใช้เปิด Drawer
      drawer: _buildDrawer(context), // สร้าง Drawer
      body: Stack(
        children: [
          GoogleMap(
            myLocationEnabled: true, // เปิดใช้งาน My Location
            initialCameraPosition: CameraPosition(
              target: _center!,
              zoom: 15,
            ), // ตำแหน่งเริ่มต้นของกล้อง
            markers: {
              Marker(
                markerId: const MarkerId('center'),
                position: _center!,
              ), // Marker ที่ตำแหน่งกลาง
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
              _controller.complete(
                controller,
              ); // เมื่อแผนที่สร้างเสร็จ ให้เก็บ controller
            },
          ),
          _buildTopBar(), // แถบด้านบน (Search)
          _buildFloatingButtons(), // ปุ่มลอยด้านข้าง
          _buildBottomSheet(), // Bottom Sheet ข้อมูล
        ],
      ),
    );
  }

  // ฟังก์ชันสำหรับสร้าง Drawer
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      width:
          MediaQuery.of(context).size.width *
          0.75, // ความกว้าง Drawer ปรับตามขนาดจอ
      child: Container(
        color: Colors.blue.shade800,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ส่วนหัวของ Drawer (ปรับขนาดตามหน้าจอ)
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                double headerHeight =
                    MediaQuery.of(context).size.height *
                    0.25; // 25% ของความสูงหน้าจอ

                // กำหนดความสูงขั้นต่ำและสูงสุด
                final double minContentHeight =
                    120.0; // ความสูงขั้นต่ำสำหรับเนื้อหาใน Header (ไอคอน, อวตาร, ชื่อ)
                final double minHeaderHeight =
                    MediaQuery.of(context).padding.top + minContentHeight;
                final double maxHeaderHeight =
                    MediaQuery.of(context).size.height *
                    0.35; // ไม่เกิน 35% ของหน้าจอ

                // จำกัดความสูงของ Header ให้อยู่ในช่วงที่เหมาะสม
                headerHeight = headerHeight.clamp(
                  minHeaderHeight,
                  maxHeaderHeight,
                );

                return SizedBox(
                  height: headerHeight,
                  child: DrawerHeader(
                    decoration: BoxDecoration(color: Colors.blue.shade900),
                    margin:
                        EdgeInsets.zero, // ลบ margin เริ่มต้นของ DrawerHeader
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      8,
                      8,
                      16,
                    ), // กำหนด padding เอง
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
                        const Spacer(), // ดัน IconButton ไปด้านบน และเนื้อหาอื่นลงล่าง
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

            // รายการเมนูใน Drawer (ใช้ DrawerListItem ที่แยกออกมา)
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
              title: 'ตัวกรอง',
              onTap: () {
                Navigator.pop(context); // ปิด Drawer ก่อน
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FilterScreen()),
                );
              },
            ),
            DrawerListItem(
              icon: Icons.history,
              title: 'ประวัติ',
              onTap: () {
                Navigator.pop(context); // ปิด Drawer ก่อน
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
              title: 'เพิ่มข้อมูล',
              onTap: () {
                Navigator.pop(context); // ปิด Drawer ก่อน
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddDataScreen(),
                  ),
                );
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
                        (context, animation1, animation2) => AuthScreen(),
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

  // ฟังก์ชันสำหรับสร้างแถบ Search ด้านบน
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
              onPressed:
                  () => _scaffoldKey.currentState?.openDrawer(), // เปิด Drawer
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
    );
  }

  // ฟังก์ชันสำหรับสร้างปุ่มลอยด้านข้าง
  Widget _buildFloatingButtons() {
    return Positioned(
      top: 110,
      right: 16,
      child: Column(
        children: [
          FloatingActionButton(
            mini: true,
            onPressed:
                _determinePosition, // ปุ่ม My Location กดแล้วดึงตำแหน่งใหม่
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            onPressed: () async {
              // ซูมเข้า
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
            onPressed: () {
              // TODO: เพิ่มฟังก์ชันสำหรับปุ่ม Pin Location (ถ้ามี)
            },
            child: const Icon(Icons.location_pin),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันสำหรับสร้าง Bottom Sheet
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
