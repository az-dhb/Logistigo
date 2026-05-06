import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  final Completer<GoogleMapController> _controller = Completer();

  LatLng? clientLocation;
  LatLng? driverLocation;
  LatLng? previousDriverLocation;

  double driverRotation = 0;

  StreamSubscription<QuerySnapshot>? _commandsSub;
  StreamSubscription<DocumentSnapshot>? _driverSub;

  String product = '';
  String status = '';

  String? uid;

  BitmapDescriptor? driverIcon;

  @override
  void initState() {
    super.initState();

    _loadDriverIcon();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    uid = user.uid;
    _listenToCommands();
  }

  Future<void> _loadDriverIcon() async {
    driverIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/arrow.png', // <-- add arrow image in assets
    );
  }

  LatLng? _parseLocation(String? location) {
    if (location == null || !location.contains(',')) return null;

    try {
      final parts = location.split(',');
      return LatLng(
        double.parse(parts[0].trim()),
        double.parse(parts[1].trim()),
      );
    } catch (e) {
      return null;
    }
  }

  void _listenToCommands() {
    if (uid == null) return;

    _commandsSub = FirebaseFirestore.instance
        .collection('commands')
        .where('status', isEqualTo: 'accepted')
        .where('clientId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;

      final data = snapshot.docs.first.data() as Map<String, dynamic>;

      clientLocation = _parseLocation(data['from']);
      product = data['product'] ?? '';
      status = data['status'] ?? '';

      if (data['driver'] != null &&
          data['driver'] is Map &&
          data['driver']['id'] != null) {
        _listenToDriver(data['driver']['id']);
      }

      _moveCamera();
      setState(() {});
    });
  }

  void _listenToDriver(String driverId) {
    _driverSub?.cancel();

    _driverSub = FirebaseFirestore.instance
        .collection('users')
        .doc(driverId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;

      if (data['location'] != null) {
        final newLocation = LatLng(
          data['location']['lat'],
          data['location']['lng'],
        );

        if (driverLocation != null) {
          previousDriverLocation = driverLocation;
        }

        driverLocation = newLocation;

        if (previousDriverLocation != null) {
          driverRotation = _calculateBearing(
            previousDriverLocation!,
            driverLocation!,
          );
        }
      }

      _moveCamera();
      setState(() {});
    });
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * pi / 180;
    double lon1 = start.longitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double lon2 = end.longitude * pi / 180;

    double dLon = lon2 - lon1;

    double y = sin(dLon) * cos(lat2);
    double x =
        cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    double bearing = atan2(y, x);

    return (bearing * 180 / pi + 360) % 360;
  }

  Future<void> _moveCamera() async {
    if (clientLocation == null || !_controller.isCompleted) return;

    final controller = await _controller.future;

    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: clientLocation!,
          zoom: 14,
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (clientLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('client'),
        position: clientLocation!,
        infoWindow: const InfoWindow(title: 'You'),
      ));
    }

    if (driverLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: driverLocation!,
        rotation: driverRotation,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        icon: driverIcon ??
            BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Driver'),
      ));
    }

    return markers;
  }

  @override
  void dispose() {
    _commandsSub?.cancel();
    _driverSub?.cancel();
    super.dispose();
  }

  Color _statusColor() {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'on_the_way':
        return Colors.orange;
      case 'delivered':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(36.7, 4.05),
              zoom: 12,
            ),
            markers: _buildMarkers(),
            onMapCreated: (controller) {
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }
            },
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory, size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.isEmpty ? 'Delivery' : product,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text('Client location'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(color: _statusColor()),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}