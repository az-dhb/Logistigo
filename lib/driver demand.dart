import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverDemandPage extends StatefulWidget {
  const DriverDemandPage({super.key});

  @override
  State<DriverDemandPage> createState() => _DriverDemandPageState();
}

class _DriverDemandPageState extends State<DriverDemandPage> {
  final demandeController = TextEditingController();
  final raisonController = TextEditingController();
  final dureeController = TextEditingController();
  final documentController = TextEditingController();

  bool isSubmitting = false;

  void submitDemand() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    if (demandeController.text.isEmpty ||
        raisonController.text.isEmpty ||
        dureeController.text.isEmpty ||
        documentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => isSubmitting = true);

    await FirebaseFirestore.instance.collection('demand').add({
      'driverId': user.uid, // ✅ added driver ID
      'demande': demandeController.text,
      'raison': raisonController.text,
      'duree': dureeController.text,
      'document': documentController.text,
      'createdAt': Timestamp.now(),
    });

    // clear form after submit
    demandeController.clear();
    raisonController.clear();
    dureeController.clear();
    documentController.clear();

    setState(() => isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Demand submitted")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _input("Demande", demandeController),
                  _input("Raison", raisonController),
                  _input("Durée", dureeController),

                  /// DOCUMENT
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: TextField(
                      controller: documentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "Document",
                        hintText: "Click to Upload File",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : submitDemand,
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
          ),
        ),
      ),
    );
  }

  Widget _input(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
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
}