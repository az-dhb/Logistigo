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
  String? driverUid;
  final primaryColor = const Color(0xFFEDA35A);

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      driverUid = user.uid;
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
      const Center(child: Text("Trucks Map Page")),
      const Center(child: Text("Analytics Page")),
      const Center(child: Text("Team Page")),
      DriverProfilePage(),
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
                ),
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
        child: Icon(icon,
            size: 26, color: isSelected ? Colors.white : Colors.white70),
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
            // ── User Info Card ─────────────────────────────────────
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
                    backgroundImage:
                    NetworkImage("https://i.pravatar.cc/150?img=3"),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text("Driver",
                            style: TextStyle(
                                color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications,
                          color: Colors.white),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // ── Pending Commands ───────────────────────────────────
            const Text("My Commands",
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            StreamBuilder<QuerySnapshot>(
              // Fetch ALL commands from collection — filter client-side
              // to avoid composite index requirement on Firestore.
              stream: FirebaseFirestore.instance
                  .collection('commands')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _errorBox(
                      "Error loading commands: ${snapshot.error}");
                }
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                // Client-side filter: driver UID matches inside the
                // 'driver' map AND status is pending
                final docs =
                (snapshot.data?.docs ?? []).where((doc) {
                  final d = doc.data() as Map<String, dynamic>;

                  // The driver field is a map — check its uid field
                  final driverMap = d['driver'];
                  String docDriverId = '';
                  if (driverMap is Map) {
                    docDriverId =
                        driverMap['uid']?.toString().trim() ?? '';
                  }

                  final status =
                      d['status']?.toString().trim().toLowerCase() ??
                          '';

                  return docDriverId == driverUid!.trim() &&
                      status == 'pending';
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Lottie.asset("assets/Not_found.json"),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return CommandCard(docId: doc.id, data: d);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: const TextStyle(color: Colors.red)),
    );
  }
}

// ================================================================
//  COMMAND CARD
// ================================================================

class CommandCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const CommandCard({Key? key, required this.docId, required this.data})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ── Parse fields ──────────────────────────────────────────────
    final String product    = data['product']?.toString()    ?? '—';
    final String quantity   = data['quantity']?.toString()   ?? '—';
    final String price      = data['price']?.toString()      ?? '—';
    final String status     = data['status']?.toString()     ?? '—';
    final String clientId   = data['clientId']?.toString()   ?? '—';
    final String from       = data['from']?.toString()       ?? '—';
    final String commandId  = data['id']?.toString()         ?? docId;

    // Truck map
    final truckMap  = data['truck']  is Map ? data['truck']  as Map : {};
    final String truckModel = truckMap['truckModel']?.toString() ?? '—';
    final String truckId    = truckMap['truckId']?.toString()    ?? '—';

    // Timestamp
    String formattedDate = '—';
    final ts = data['timestamp'];
    if (ts is Timestamp) {
      final dt = ts.toDate();
      formattedDate =
      '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Orange header ──────────────────────────────────────
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFEDA35A),
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Command ID
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Command ID",
                        style: TextStyle(
                            color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(commandId,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ],
                ),
                // Pending badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.hourglass_empty_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text("PENDING",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                // Product + Quantity + Price
                Row(
                  children: [
                    Expanded(
                        child: _infoBlock(
                            Icons.inventory_2_outlined,
                            "Product",
                            product)),
                    _divider(),
                    Expanded(
                        child: _infoBlock(
                            Icons.format_list_numbered_rounded,
                            "Quantity",
                            quantity)),
                    _divider(),
                    Expanded(
                        child: _infoBlock(
                            Icons.attach_money_rounded,
                            "Price",
                            "$price DA")),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // From + Client
                Row(
                  children: [
                    Expanded(
                        child: _infoBlock(
                            Icons.location_on_outlined,
                            "From",
                            from)),
                    _divider(),
                    Expanded(
                        child: _infoBlock(
                            Icons.person_outline_rounded,
                            "Client ID",
                            clientId)),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Truck info
                Row(
                  children: [
                    Expanded(
                        child: _infoBlock(
                            Icons.local_shipping_outlined,
                            "Truck Model",
                            truckModel)),
                    _divider(),
                    Expanded(
                        child: _infoBlock(
                            Icons.badge_outlined,
                            "Truck ID",
                            truckId)),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Timestamp
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(formattedDate,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Update Status Button ───────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEDA35A),
                      foregroundColor: Colors.white,
                      padding:
                      const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text("Update Status",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    onPressed: () =>
                        _showUpdateDialog(context, docId, status),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  Widget _divider() =>
      Container(width: 1, height: 36, color: Colors.grey[200]);

  Widget _infoBlock(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(
      BuildContext context, String docId, String currentStatus) {
    String selectedStatus = "delivered";
    final TextEditingController noteController =
    TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text("Update Command Status"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(
                      value: "delivered",
                      child: Text("Delivered")),
                  DropdownMenuItem(
                      value: "stopped", child: Text("Stopped")),
                ],
                onChanged: (val) {
                  setStateDialog(() => selectedStatus = val!);
                },
              ),
              if (selectedStatus == "stopped") ...[
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: "Reason for stopping",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEDA35A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final update = <String, dynamic>{
                  'status': selectedStatus,
                };
                if (selectedStatus == "stopped") {
                  update['reason'] =
                      noteController.text.trim();
                } else {
                  update['reason'] = "";
                }
                await FirebaseFirestore.instance
                    .collection('commands')
                    .doc(docId)
                    .update(update);
                Navigator.pop(ctx);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}