import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientHistoryPage extends StatelessWidget {
  const ClientHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),

      body: SafeArea(
        child: Column(
          children: [

            /// 🔍 SEARCH BAR
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Track Number",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            /// 📦 LIST
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('commands')
                    .where('clientId', isEqualTo: user!.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  /// ❗ FILTER STATUS
                  final filtered = docs.where((doc) {
                    final status = doc['status'];
                    return status != "requested" &&
                        status != "pending" &&
                        status != "accepted";
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text("No history yet"),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final data = filtered[index];

                      final product = data['product'] ?? "Unknown";
                      final id = data['id'] ?? "";
                      final status = data['status'] ?? "";

                      /// ✅ FIX: Firestore int64 → Dart safe conversion
                      final priceValue = data['price'];
                      final String price = priceValue != null
                          ? priceValue.toString()
                          : "0";

                      Color statusColor;
                      if (status == "Arrived" || status == "arrived") {
                        statusColor = Colors.green;
                      } else if (status == "Canceled") {
                        statusColor = Colors.red;
                      } else {
                        statusColor = Colors.black;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),

                        child: Row(
                          children: [

                            /// LEFT TEXT
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  Text(
                                    product,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    id,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  const Text("Status"),

                                  Text(
                                    status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  const Text("Price"),

                                  Text(
                                    price,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            /// 📦 BOX IMAGE
                            Image.asset(
                              "assets/packaging.png",
                              width: 90,
                              height: 90,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            /// 🔻 BOTTOM NAV
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  Icon(Icons.home),
                  Icon(Icons.add_circle_outline),
                  Icon(Icons.location_on_outlined),
                  Icon(Icons.access_time),
                  Icon(Icons.person_outline),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}