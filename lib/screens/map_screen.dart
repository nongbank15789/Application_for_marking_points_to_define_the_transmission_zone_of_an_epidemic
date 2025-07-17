import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  LatLng _center = const LatLng(18.7883, 98.9853);
  final double _circleRadius = 300;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      setState(() {
        _center = LatLng(pos.latitude, pos.longitude);
      });
    } catch (e) {
      debugPrint('ตำแหน่งไม่พร้อม: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            myLocationEnabled: true,
            initialCameraPosition: CameraPosition(target: _center, zoom: 15),
            markers: {
              Marker(markerId: const MarkerId('center'), position: _center)
            },
            circles: {
              Circle(
                circleId: const CircleId('danger_zone'),
                center: _center,
                radius: _circleRadius,
                fillColor: Colors.red.withOpacity(0.2),
                strokeColor: Colors.red.withOpacity(0.5),
                strokeWidth: 2,
              )
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
                children: const [
                  Icon(Icons.menu, color: Colors.white),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text('Search',
                        style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                  Icon(Icons.search, color: Colors.white),
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
                  onPressed: () {},
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: () {},
                  child: const Icon(Icons.center_focus_strong),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: () {},
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
                      Text('ระดับความอันตราย: ',
                          style: TextStyle(fontSize: 16)),
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
          ),
        ],
      ),
    );
  }
}
