import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

// ── Data model ───────────────────────────────────────────────────────────────

class CommandModel {
  final String id;
  final String product;
  final String status;
  final String? quantity;
  final int? price;
  final LatLng? clientLocation;
  final String? driverId;
  final String? driverName;

  CommandModel({
    required this.id,
    required this.product,
    required this.status,
    this.quantity,
    this.price,
    this.clientLocation,
    this.driverId,
    this.driverName,
  });
}

// ── Page ─────────────────────────────────────────────────────────────────────

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  final Completer<GoogleMapController> _mapController = Completer();

  List<CommandModel> _commands = [];
  int _selectedIndex = 0;

  final Map<String, LatLng?> _driverLocations = {};
  final Map<String, LatLng?> _prevDriverLocations = {};
  final Map<String, double> _driverRotations = {};

  StreamSubscription<QuerySnapshot>? _commandsSub;
  final Map<String, StreamSubscription<DocumentSnapshot>> _driverSubs = {};

  BitmapDescriptor? _driverIcon;

  String? _uid;

  // ── User's own live location ─────────────────────────────────────────────
  LatLng? _myLocation;
  StreamSubscription<Position>? _locationSub;

  final DraggableScrollableController _sheetController =
  DraggableScrollableController();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadDriverIcon();
    _startMyLocation();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _uid = user.uid;

    _listenToCommands();
  }

  @override
  void dispose() {
    _commandsSub?.cancel();
    _locationSub?.cancel();
    for (final sub in _driverSubs.values) {
      sub.cancel();
    }
    _sheetController.dispose();
    super.dispose();
  }

  // ── User location ─────────────────────────────────────────────────────────

  Future<void> _startMyLocation() async {
    // Check / request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) return;

    // Get an immediate fix first
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}

    // Then stream continuous updates
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // metres before next update
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
    });
  }

  // ── Icon ──────────────────────────────────────────────────────────────────

  Future<void> _loadDriverIcon() async {
    try {
      final icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/arrow.png',
      );
      if (mounted) setState(() => _driverIcon = icon);
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  LatLng? _parseLocation(String? location) {
    if (location == null || !location.contains(',')) return null;
    try {
      final parts = location.split(',');
      return LatLng(
        double.parse(parts[0].trim()),
        double.parse(parts[1].trim()),
      );
    } catch (_) {
      return null;
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * pi / 180;
    final lon1 = start.longitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final lon2 = end.longitude * pi / 180;
    final dLon = lon2 - lon1;
    final y = sin(dLon) * cos(lat2);
    final x =
        cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  // ── Firebase ──────────────────────────────────────────────────────────────

  void _listenToCommands() {
    if (_uid == null) return;

    _commandsSub = FirebaseFirestore.instance
        .collection('commands')
        .where('status', isEqualTo: 'accepted')
        .where('clientId', isEqualTo: _uid)
        .snapshots()
        .listen((snapshot) async {
      final List<CommandModel> commands = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final driverId = (data['driver'] is Map)
            ? data['driver']['id'] as String?
            : null;

        String? driverName;
        if (driverId != null) {
          final driverDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(driverId)
              .get();
          if (driverDoc.exists) {
            driverName =
            (driverDoc.data() as Map<String, dynamic>)['username']
            as String?;
          }
          _subscribeToDriver(driverId);
        }

        commands.add(CommandModel(
          id: doc.id,
          product: data['product'] ?? '',
          status: data['status'] ?? '',
          quantity: data['quantity']?.toString(),
          price: data['price'] is int ? data['price'] as int : null,
          clientLocation: _parseLocation(data['from'] as String?),
          driverId: driverId,
          driverName: driverName,
        ));
      }

      final activeDriverIds =
      commands.map((c) => c.driverId).whereType<String>().toSet();
      _driverSubs.keys
          .where((id) => !activeDriverIds.contains(id))
          .toList()
          .forEach((id) {
        _driverSubs[id]?.cancel();
        _driverSubs.remove(id);
        _driverLocations.remove(id);
        _prevDriverLocations.remove(id);
        _driverRotations.remove(id);
      });

      if (mounted) {
        setState(() {
          _commands = commands;
          if (_selectedIndex >= commands.length) _selectedIndex = 0;
        });
        _focusOnSelected();
      }
    });
  }

  void _subscribeToDriver(String driverId) {
    if (_driverSubs.containsKey(driverId)) return;

    _driverSubs[driverId] = FirebaseFirestore.instance
        .collection('users')
        .doc(driverId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;
      final data = doc.data() as Map<String, dynamic>;
      if (data['location'] == null) return;

      final newLocation = LatLng(
        (data['location']['lat'] as num).toDouble(),
        (data['location']['lng'] as num).toDouble(),
      );

      setState(() {
        _prevDriverLocations[driverId] = _driverLocations[driverId];
        _driverLocations[driverId] = newLocation;

        final prev = _prevDriverLocations[driverId];
        if (prev != null) {
          _driverRotations[driverId] =
              _calculateBearing(prev, newLocation);
        }
      });

      final selected = _selectedCommand;
      if (selected != null && selected.driverId == driverId) {
        _moveCameraTo(newLocation);
      }
    });
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  CommandModel? get _selectedCommand =>
      _commands.isNotEmpty ? _commands[_selectedIndex] : null;

  Future<void> _focusOnSelected() async {
    final cmd = _selectedCommand;
    if (cmd == null || !_mapController.isCompleted) return;

    final driverLoc =
    cmd.driverId != null ? _driverLocations[cmd.driverId!] : null;
    final target = driverLoc ?? cmd.clientLocation ?? _myLocation;
    if (target != null) _moveCameraTo(target);
  }

  Future<void> _moveCameraTo(LatLng target) async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 15),
      ),
    );
  }

  // ── Markers ───────────────────────────────────────────────────────────────

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // ── "You" marker – user's live device location ────────────────────────
    if (_myLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('me'),
        position: _myLocation!,
        anchor: const Offset(0.5, 0.5),
        zIndex: 2, // always on top
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet),
        infoWindow: const InfoWindow(
          title: 'You',
          snippet: 'Your current location',
        ),
      ));
    }

    // ── Per-command markers ───────────────────────────────────────────────
    for (final cmd in _commands) {
      // Pickup / client address from the command document
      if (cmd.clientLocation != null) {
        markers.add(Marker(
          markerId: MarkerId('client_${cmd.id}'),
          position: cmd.clientLocation!,
          infoWindow: InfoWindow(
            title: cmd.product.isEmpty ? 'Pickup' : cmd.product,
            snippet: 'Pickup point',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed),
        ));
      }

      // Driver marker
      final driverId = cmd.driverId;
      if (driverId != null && _driverLocations[driverId] != null) {
        markers.add(Marker(
          markerId: MarkerId('driver_${cmd.id}'),
          position: _driverLocations[driverId]!,
          rotation: _driverRotations[driverId] ?? 0,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          icon: _driverIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: cmd.driverName ?? 'Driver',
            snippet: cmd.product,
          ),
        ));
      }
    }

    return markers;
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return const Color(0xFF22C55E);
      case 'on_the_way':
        return const Color(0xFFF97316);
      case 'delivered':
        return const Color(0xFF3B82F6);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'on_the_way':
        return 'On the way';
      case 'delivered':
        return 'Delivered';
      default:
        return status;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomNavHeight =
        kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: false,
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          Positioned.fill(
            bottom: bottomNavHeight,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _myLocation ?? const LatLng(36.7, 4.05),
                zoom: 13,
              ),
              markers: _buildMarkers(),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (controller) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(controller);
                }
              },
            ),
          ),

          // ── Top bar ───────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _GlassButton(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GlassCard(
                      child: Row(
                        children: [
                          const Icon(Icons.local_shipping_outlined,
                              size: 20, color: Color(0xFF6366F1)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _commands.isEmpty
                                  ? 'No active deliveries'
                                  : '${_commands.length} active deliver'
                                  '${_commands.length == 1 ? 'y' : 'ies'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Recenter on "You" button
                  if (_myLocation != null)
                    _GlassButton(
                      onTap: () => _moveCameraTo(_myLocation!),
                      child: const Icon(Icons.my_location_rounded,
                          size: 18, color: Color(0xFF6366F1)),
                    ),
                ],
              ),
            ),
          ),

          // ── Draggable sheet ───────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(bottom: bottomNavHeight),
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.38,
              minChildSize: 0.20,
              maxChildSize: 0.80,
              snap: true,
              snapSizes: const [0.20, 0.38, 0.60, 0.80],
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 24,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SingleChildScrollView(
                        controller: scrollController,
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20),
                              child: Row(
                                children: [
                                  const Text(
                                    'Ongoing Orders',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Live location indicator
                                  if (_myLocation != null) ...[
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF8B5CF6),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'You',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF8B5CF6),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  if (_commands.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1)
                                            .withOpacity(0.12),
                                        borderRadius:
                                        BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${_commands.length}',
                                        style: const TextStyle(
                                          color: Color(0xFF6366F1),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _commands.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              16, 0, 16, 16),
                          itemCount: _commands.length,
                          itemBuilder: (context, index) {
                            return _CommandCard(
                              command: _commands[index],
                              isSelected: _selectedIndex == index,
                              driverLocation:
                              _commands[index].driverId != null
                                  ? _driverLocations[
                              _commands[index].driverId!]
                                  : null,
                              statusColor: _statusColor(
                                  _commands[index].status),
                              statusLabel: _statusLabel(
                                  _commands[index].status),
                              onTap: () {
                                setState(
                                        () => _selectedIndex = index);
                                _focusOnSelected();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No accepted orders yet',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _CommandCard extends StatelessWidget {
  final CommandModel command;
  final bool isSelected;
  final LatLng? driverLocation;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onTap;

  const _CommandCard({
    required this.command,
    required this.isSelected,
    required this.driverLocation,
    required this.statusColor,
    required this.statusLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withOpacity(0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ]
              : [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  color: Color(0xFF6366F1), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    command.product.isEmpty
                        ? 'Package'
                        : command.product,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (command.quantity != null) ...[
                        Text(
                          'Qty: ${command.quantity}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (command.price != null)
                        Text(
                          '${command.price} DA',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  if (command.driverName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 13, color: Color(0xFF6366F1)),
                        const SizedBox(width: 4),
                        Text(
                          command.driverName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (driverLocation != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Live',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _GlassButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}