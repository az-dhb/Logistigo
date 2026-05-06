import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logistigo/Login.dart';
import 'package:logistigo/driver demand.dart';
import 'package:logistigo/driver forum.dart';
import 'package:logistigo/driver update.dart';
import 'package:geolocator/geolocator.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission(); // ✅ ADDED
  }

  /// ✅ ADDED LOCATION FUNCTION
  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = [
      _buildHome(user),
      const AcceptedCommandsPage(),
      const DriverFormPage(),
      const DriverDemandPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),

      extendBody: true,

      body: SafeArea(child: pages[currentIndex]),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 25,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(Icons.assignment, 0),
              _navItem(Icons.inventory_2, 1),
              _navItem(Icons.edit, 2),
              _navItem(Icons.analytics, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildHome(User user) {
    return Column(
      children: [
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              );
            }

            var data = snapshot.data!;
            String username = data['username'];

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Welcome Back",
                          style: GoogleFonts.poppins(color: Colors.grey)),
                      const SizedBox(height: 5),
                      Text("Hi, $username!",
                          style: GoogleFonts.poppins(
                              fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(user.email ?? "",
                          style: GoogleFonts.poppins(color: Colors.grey)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.black),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();

                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => LoginPage()),
                              (route) => false,
                        );
                      }
                    },
                  )
                ],
              ),
            );
          },
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('commands')
                .where('driver.uid', isEqualTo: user.uid)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    "No pending commands",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var cmd = docs[index];
                  var data = cmd.data() as Map<String, dynamic>;

                  return CommandCard(
                    id: cmd.id,
                    product: data['product'] is Map
                        ? data['product']['name'] ?? ''
                        : data['product']?.toString() ?? '',
                    from: data['from'] is Map
                        ? data['from']['name'] ?? ''
                        : data['from']?.toString() ?? '',
                    quantity: data['quantity']?.toString() ?? '',
                    truck: data['truck'] is Map
                        ? data['truck']['truckModel'] ?? ''
                        : data['truck']?.toString() ?? '',
                    garage: data['garage'] is Map
                        ? data['garage']['name'] ?? ''
                        : data['garage']?.toString() ?? '',
                    date: data['date'] is Timestamp
                        ? data['date']
                        : Timestamp.now(),
                    price: (data['price'] as num).toDouble(),
                    status: data['status'] ?? '',
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class CommandCard extends StatefulWidget {
  final String id;
  final String product;
  final Timestamp date;
  final double price;
  final String status;

  final String from;
  final String quantity;
  final String truck;
  final String garage;

  const CommandCard({
    super.key,
    required this.id,
    required this.product,
    required this.date,
    required this.price,
    required this.status,
    required this.from,
    required this.quantity,
    required this.truck,
    required this.garage,
  });

  @override
  State<CommandCard> createState() => _CommandCardState();
}

class _CommandCardState extends State<CommandCard> {
  String? selectedReason;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.id,
                style: GoogleFonts.poppins(color: Colors.grey)),

            const SizedBox(height: 10),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _info("From", widget.from),
                      _info("Product", widget.product),
                      _info("Quantity", widget.quantity),
                    ],
                  ),
                ),
                Image.asset("assets/packaging.png", width: 160)
              ],
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniInfo("Truck", widget.truck),
                _miniInfo("Garage", widget.garage),
                _miniInfo(
                  "Date",
                  widget.date.toDate().toString().substring(0, 16),
                ),
              ],
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              hint: Text("Reason (if refusing)",
                  style: GoogleFonts.poppins()),
              value: selectedReason,
              items: ["Busy", "Truck issue", "Other"]
                  .map((e) =>
                  DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  selectedReason = val;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('commands')
                          .doc(widget.id)
                          .update({
                        'status': 'refused',
                        'reason': selectedReason
                      });
                    },
                    child: Text("Refuse",
                        style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('commands')
                          .doc(widget.id)
                          .update({'status': 'accepted'});
                    },
                    child: Text("Accept",
                        style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _info(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _miniInfo(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.grey)),
        Text(value,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}