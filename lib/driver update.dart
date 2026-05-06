import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class AcceptedCommandsPage extends StatelessWidget {
  const AcceptedCommandsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('commands')
              .where('driver.uid', isEqualTo: user.uid)
              .where('status', isEqualTo: 'accepted')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Text(
                  "No active deliveries",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 10, bottom: 20),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final raw = docs[index].data();

                if (raw == null || raw is! Map<String, dynamic>) {
                  return const SizedBox();
                }

                final data = raw;

                final from = _safeText(data['from'], key: 'name');
                final truck = _safeText(data['truck'], key: 'truckModel');

                final price = _safeDouble(data['price']);

                return AcceptedCommandCard(
                  id: docs[index].id,
                  product: _safeString(data['product']),
                  date: data['date'] is Timestamp
                      ? data['date']
                      : Timestamp.now(),
                  price: price,
                  from: from,
                  quantity: _safeString(data['quantity']),
                  truck: truck,
                  garage: _safeString(data['garage']),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // -------- SAFE HELPERS --------

  String _safeString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  String _safeText(dynamic value, {required String key}) {
    if (value is Map && value[key] != null) {
      return value[key].toString();
    }
    return value?.toString() ?? '';
  }

  double _safeDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}

class AcceptedCommandCard extends StatefulWidget {
  final String id;
  final String product;
  final Timestamp date;
  final double price;
  final String from;
  final String quantity;
  final String truck;
  final String garage;

  const AcceptedCommandCard({
    super.key,
    required this.id,
    required this.product,
    required this.date,
    required this.price,
    required this.from,
    required this.quantity,
    required this.truck,
    required this.garage,
  });

  @override
  State<AcceptedCommandCard> createState() => _AcceptedCommandCardState();
}

class _AcceptedCommandCardState extends State<AcceptedCommandCard> {
  String? selectedReason;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
                      _info("Truck", widget.truck),
                    ],
                  ),
                ),
                Image.asset(
                  "assets/packaging.png",
                  width: 90,
                  errorBuilder: (c, e, s) =>
                  const Icon(Icons.local_shipping),
                )
              ],
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: selectedReason,
              hint: Text(
                "Raison (panne)",
                style: GoogleFonts.poppins(),
              ),
              items: const [
                "Flat tire",
                "Engine issue",
                "Other"
              ].map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e),
                );
              }).toList(),
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
                      backgroundColor: Colors.orange.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('commands')
                          .doc(widget.id)
                          .update({
                        'status': 'problem',
                        'reason': selectedReason ?? '',
                      });
                    },
                    child: Text("Panne",
                        style: GoogleFonts.poppins()),
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
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('commands')
                          .doc(widget.id)
                          .update({'status': 'arrived'});

                      if (user != null) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .update({
                          'deliveries': FieldValue.increment(1),
                        });
                      }
                    },
                    child: Text("Arrived",
                        style: GoogleFonts.poppins()),
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
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            value.isEmpty ? '-' : value,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}