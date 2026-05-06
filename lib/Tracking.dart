import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrucksMapPage extends StatefulWidget {
  const TrucksMapPage({super.key});

  @override
  _TrucksMapPageState createState() => _TrucksMapPageState();
}

class _TrucksMapPageState extends State<TrucksMapPage> {
  final Completer<GoogleMapController> _controller = Completer();

  // Live markers for drivers
  final Map<String, Marker> _markers = {};

  // Primary UI colors
  final Color primaryColor = const Color(0xFF5A83AF);
  final Color accentColor = const Color(0xFFEDA35A);

  // Initial map position
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(36.7538, 3.0588), // Center on Algeria
    zoom: 6,
  );

  @override
  void initState() {
    super.initState();
    _listenToDrivers();
  }

  void _listenToDrivers() {
    FirebaseFirestore.instance
        .collection('drivers')
        .snapshots()
        .listen((snapshot) {
      final Map<String, Marker> newMarkers = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('lat') && data.containsKey('lng')) {
          newMarkers[doc.id] = Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(data['lat'], data['lng']),
            infoWindow: InfoWindow(
              title: data['name'] ?? "Driver",
              snippet: "Truck ID: ${data['truckId'] ?? doc.id}",
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          );
        }
      }

      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          // 🌍 Google Map
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers.values.toSet(),
            onMapCreated: (controller) => _controller.complete(controller),
            myLocationEnabled: true,
            zoomControlsEnabled: false,
          ),

          // 🟦 Floating top bar with title
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.local_shipping_rounded, color: primaryColor),
                  const SizedBox(width: 12),
                  Text(
                    "Live Truck Tracker",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🟧 Floating bottom legend
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _legendItem(accentColor, "Delivering"),
                  _legendItem(primaryColor, "Idle"),
                  _legendItem(Colors.red, "Delayed"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Legend item
  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}