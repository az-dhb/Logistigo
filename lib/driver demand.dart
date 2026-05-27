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
      'driverId': user.uid,
      'demande': demandeController.text,
      'raison': raisonController.text,
      'duree': dureeController.text,
      'document': documentController.text,
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });

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
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ── Form Card ──────────────────────────────────────────
              Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _input("Demande", demandeController),
                    _input("Raison", raisonController),
                    _input("Durée", dureeController),

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
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── My Demands Section ─────────────────────────────────
              if (user != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "My Demands",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  // ← no .where('status') filter, no .orderBy → returns everything
                  stream: FirebaseFirestore.instance
                      .collection('demand')
                      .where('driverId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          "Error: ${snapshot.error}",
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                            )
                          ],
                        ),
                        child: Text(
                          "No demands submitted yet.",
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    // sort by createdAt descending in Dart — no composite index needed
                    final docs = snapshot.data!.docs.toList()
                      ..sort((a, b) {
                        final aTime =
                            (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                        final bTime =
                            (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                        return bTime.compareTo(aTime);
                      });

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final status =
                        (data['status'] ?? 'pending').toString().trim().toLowerCase();
                        final demande = data['demande'] ?? '';
                        final raison = data['raison'] ?? '';
                        final duree = data['duree'] ?? '';
                        final createdAt = data['createdAt'] as Timestamp?;

                        final isAccepted = status == 'accepted';
                        final isRefused = status == 'refused';
                        final isDecided = isAccepted || isRefused;

                        Color statusColor;
                        Color statusBg;
                        IconData statusIcon;
                        String statusLabel;

                        if (isAccepted) {
                          statusColor = const Color(0xFF1E7D3E);
                          statusBg = const Color(0xFFE6F4EC);
                          statusIcon = Icons.check_circle_rounded;
                          statusLabel = "Accepted";
                        } else if (isRefused) {
                          statusColor = const Color(0xFFB71C1C);
                          statusBg = const Color(0xFFFDECEC);
                          statusIcon = Icons.cancel_rounded;
                          statusLabel = "Refused";
                        } else {
                          statusColor = const Color(0xFF7A6000);
                          statusBg = const Color(0xFFFFF8E1);
                          statusIcon = Icons.hourglass_top_rounded;
                          statusLabel = "Pending";
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: isDecided
                                ? Border.all(
                              color: statusColor.withOpacity(0.4),
                              width: 1.5,
                            )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Status banner for accepted / refused ──
                              if (isDecided)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(18)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(statusIcon,
                                          color: statusColor, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          isAccepted
                                              ? "The manager has accepted your demand"
                                              : "The manager has refused your demand",
                                          style: GoogleFonts.poppins(
                                            color: statusColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // ── Card body ──
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            demande,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        // show pill badge for every status
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusBg,
                                            borderRadius:
                                            BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(statusIcon,
                                                  size: 13,
                                                  color: statusColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                statusLabel,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: statusColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    _detailRow(
                                        Icons.info_outline, "Reason", raison),
                                    _detailRow(
                                        Icons.access_time, "Duration", duree),
                                    if (createdAt != null)
                                      _detailRow(
                                        Icons.calendar_today_outlined,
                                        "Submitted",
                                        _formatDate(createdAt.toDate()),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            "$label: ",
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
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