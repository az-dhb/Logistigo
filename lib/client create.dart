import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  String? selectedSupplierId;
  String? selectedProduct;

  List<String> products = [];

  final TextEditingController quantityController = TextEditingController();
  String locationText = "Get Location";

  String generateOrderId() {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    final rand = Random();
    return List.generate(12, (index) => chars[rand.nextInt(chars.length)])
        .join();
  }

  Future<void> getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition();

    setState(() {
      locationText = "${pos.latitude}, ${pos.longitude}";
    });
  }

  Future<void> loadProducts(String supplierId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(supplierId)
        .get();

    final data = doc.data();

    setState(() {
      products = List<String>.from(data?['products'] ?? []);
      selectedProduct = null;
    });
  }

  Future<void> createOrder() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null ||
        selectedSupplierId == null ||
        selectedProduct == null ||
        quantityController.text.isEmpty ||
        locationText == "Get Location") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    final orderId = generateOrderId();

    try {
      await FirebaseFirestore.instance.collection('commands').add({
        "id": orderId,
        "supplierId": selectedSupplierId,
        "clientId": user.uid,
        "product": selectedProduct,
        "quantity": quantityController.text, // ✅ STRING
        "from": locationText,
        "status": "requested",
        "timestamp": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Order Created Successfully")),
      );

      // Reset form
      setState(() {
        selectedSupplierId = null;
        selectedProduct = null;
        products = [];
        quantityController.clear();
        locationText = "Get Location";
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),

          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                )
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Center(
                  child: Text(
                    "New Order",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                /// SUPPLIER
                const Text("Select Supplier"),
                const SizedBox(height: 8),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'manager')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final suppliers = snapshot.data!.docs;

                    return DropdownButtonFormField<String>(
                      value: selectedSupplierId,
                      items: suppliers.map((doc) {
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(doc['username']),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        setState(() {
                          selectedSupplierId = value;
                        });
                        await loadProducts(value!);
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                /// PRODUCT
                const Text("Select Product"),
                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  value: selectedProduct,
                  items: products.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text(p),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedProduct = value;
                    });
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// LOCATION
                const Text("Your Location"),
                const SizedBox(height: 8),

                GestureDetector(
                  onTap: getLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(locationText)),
                        const Icon(Icons.location_on)
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// QUANTITY
                const Text("Quantity"),
                const SizedBox(height: 8),

                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "Enter quantity",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                /// BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: createOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Confirm Order",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}