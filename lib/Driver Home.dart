import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logistigo/Driver%20Profile.dart';
import 'package:lottie/lottie.dart';

class DriverPage extends StatefulWidget {
  const DriverPage({super.key});

  @override
  _DriverPageState createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  String userName = 'Driver';
  String? driverUid; // Firebase UID
  final primaryColor = const Color(0xFFEDA35A);

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  /// Load driver's name and UID
  Future<void> _loadDriverData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      driverUid = user.uid; // set UID
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            userName = data['username'] ?? data['email'] ?? "Driver";
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _dashboardBody(),
      const Center(child: Text("Trucks Map Page")), // placeholder
      const Center(child: Text("Analytics Page")), // placeholder
      const Center(child: Text("Team Page")), // placeholder
      DriverProfilePage(), // placeholder
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7D6B6),
      extendBody: true,
      body: pages[_selectedIndex],
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF5A83AF),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.dashboard_customize_rounded, 0),
                _buildNavItem(Icons.local_shipping_rounded, 1),
                _buildNavItem(Icons.analytics_outlined, 2),
                _buildNavItem(Icons.groups_rounded, 3),
                _buildNavItem(Icons.person_outline_rounded, 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 26,
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
    );
  }

  Widget _dashboardBody() {
    if (driverUid == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage("https://i.pravatar.cc/150?img=3"),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Driver",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications, color: Colors.white),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              "My Shipments",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),

            /// Shipments List filtered by driverUid
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shipments')
                  .where('driverUid', isEqualTo: driverUid)
                  .orderBy('arrivalDate')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Lottie.asset("assets/Not_found.json"),
                  );
                }

                final docs = snapshot.data!.docs;

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return ShipmentCard(
                      docId: doc.id,
                      trackingNumber: data['trackingNumber'] ?? '',
                      status: data['status'] ?? 'Pending',
                      customer: data['customer'] ?? '',
                      from: data['from'] ?? '',
                      to: data['to'] ?? '',
                      arrivalDate: data['arrivalDate'] ?? '',
                      reason: data['reason'] ?? '',
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 🔴 Shipment Card with Status Update
class ShipmentCard extends StatelessWidget {
  final String docId;
  final String trackingNumber;
  final String status;
  final String customer;
  final String from;
  final String to;
  final String arrivalDate;
  final String reason;

  const ShipmentCard({
    Key? key,
    required this.docId,
    required this.trackingNumber,
    required this.status,
    required this.customer,
    required this.from,
    required this.to,
    required this.arrivalDate,
    required this.reason,
  }) : super(key: key);

  Color getStatusColor() {
    switch (status.toLowerCase()) {
      case "delivered":
        return Colors.green;
      case "pending":
        return Colors.orange;
      case "stopped":
        return Colors.red;
      default:
        return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEDA35A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Tracking + Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Tracking Number", style: TextStyle(color: Colors.white70)),
                  Text(
                    "№ $trackingNumber",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: getStatusColor(),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () => _updateShipmentStatus(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 25),

          /// Customer / From / To
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoColumn("Customer", customer),
              _infoColumn("From", from),
              _infoColumn("To", to),
            ],
          ),
          const SizedBox(height: 25),

          /// Arrival Date
          const Text("Arrival date", style: TextStyle(color: Colors.white70)),
          Text(
            arrivalDate,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),

          /// Reason (if stopped)
          if (status.toLowerCase() == "stopped") ...[
            const SizedBox(height: 8),
            Text("Reason: $reason",
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Widget _infoColumn(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _updateShipmentStatus(BuildContext context) {
    final TextEditingController reasonController = TextEditingController();
    String selectedStatus = status;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Update Shipment Status"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedStatus,
                items: const [
                  DropdownMenuItem(value: "Pending", child: Text("Pending")),
                  DropdownMenuItem(value: "Delivered", child: Text("Delivered")),
                  DropdownMenuItem(value: "Stopped", child: Text("Stopped")),
                ],
                onChanged: (val) {
                  setStateDialog(() {
                    selectedStatus = val!;
                  });
                },
              ),
              if (selectedStatus == "Stopped") ...[
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: "Reason"),
                ),
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEDA35A)),
              onPressed: () async {
                final updateData = {'status': selectedStatus};
                if (selectedStatus == "Stopped") {
                  updateData['reason'] = reasonController.text.trim();
                } else {
                  updateData['reason'] = "";
                }

                await FirebaseFirestore.instance
                    .collection('shipments')
                    .doc(docId)
                    .update(updateData);

                Navigator.pop(context);
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}