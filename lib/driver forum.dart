import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverFormPage extends StatelessWidget {
  const DriverFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        title: const Text("Driver Forms"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('commands')
            .where('driver.uid', isEqualTo: user.uid)
            .where('status', whereIn: ['arrived', 'en panne'])
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Text(
                "No forms to fill",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data =
              docs[index].data() as Map<String, dynamic>;

              return DriverFormCard(
                commandId: docs[index].id,
                product: data['product'] ?? '',

                /// ✅ FIX HERE
                from: data['from'] is Map
                    ? data['from']['name'] ?? ''
                    : data['from'] ?? '',

                quantity: data['quantity']?.toString() ?? '',

                truck: data['truck'] is Map
                    ? data['truck']['model'] ?? ''
                    : data['truck'] ?? '',
              );
            },
          );
        },
      ),
    );
  }
}
class DriverFormCard extends StatefulWidget {
  final String commandId;
  final String product;
  final String from;
  final String quantity;
  final String truck;

  const DriverFormCard({
    super.key,
    required this.commandId,
    required this.product,
    required this.from,
    required this.quantity,
    required this.truck,
  });

  @override
  State<DriverFormCard> createState() => _DriverFormCardState();
}

class _DriverFormCardState extends State<DriverFormCard> {
  final distanceController = TextEditingController();
  final carburantController = TextEditingController();
  final problemeController = TextEditingController();
  final commentaireController = TextEditingController();

  bool isSubmitting = false;

  void submitForm() async {
    if (distanceController.text.isEmpty ||
        carburantController.text.isEmpty ||
        problemeController.text.isEmpty ||
        commentaireController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all fields")),
      );
      return;
    }

    setState(() => isSubmitting = true);

    await FirebaseFirestore.instance.collection('forms').add({
      'commandId': widget.commandId,
      'distance': distanceController.text,
      'carburant': carburantController.text,
      'probleme': problemeController.text,
      'commentaire': commentaireController.text,
      'createdAt': Timestamp.now(),
    });

    await FirebaseFirestore.instance
        .collection('commands')
        .doc(widget.commandId)
        .update({'status': 'done'});

    setState(() => isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.commandId,
                style: GoogleFonts.poppins(color: Colors.grey)),

            const SizedBox(height: 10),

            Row(
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
                Image.asset("assets/packaging.png", width: 120)
              ],
            ),

            const SizedBox(height: 15),

            _input("Distance", distanceController),
            _input("Carburant", carburantController),
            _input("Problème", problemeController),
            _input("Commentaire", commentaireController, maxLines: 3),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  isSubmitting ? "Submitting..." : "Submit",
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _input(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: "Value",
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
}