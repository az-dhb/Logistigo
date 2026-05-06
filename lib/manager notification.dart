import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            FormsSection(),
            SizedBox(height: 16),
            CommandsSection(),
            SizedBox(height: 16),
            FormsSectionCards(), // 🔥 NEW
          ],
        ),
      ),
    );
  }
}

//// ================= DEMAND =================

class FormsSection extends StatelessWidget {
  const FormsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('demand')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final forms = snapshot.data!.docs;

        return Column(
          children: forms.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return FormCard(data: data, docId: doc.id);
          }).toList(),
        );
      },
    );
  }
}

class FormCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const FormCard({
    super.key,
    required this.data,
    required this.docId,
  });

  Future<void> _updateStatus(String status) async {
    await FirebaseFirestore.instance
        .collection('demand')
        .doc(docId)
        .update({'status': status});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardStyle(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: AssetImage("assets/chauffeur.png"),
              ),
              SizedBox(width: 10),
              Text("Driver Request",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoBlock("Demande", data['demande']),
              _infoBlock("Durée", data['duree']),
              _infoBlock("Raison", data['raison']),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Row(
              children: [
                Expanded(child: Text(data['document'] ?? 'No document')),
                const Icon(Icons.download),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateStatus("refused"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[200],
                    foregroundColor: Colors.red[800],
                  ),
                  child: const Text("Refuse"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateStatus("accepted"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[300],
                    foregroundColor: Colors.green[900],
                  ),
                  child: const Text("Accept"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBlock(String title, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value?.toString() ?? '',
            style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

//// ================= COMMANDS =================

class CommandsSection extends StatelessWidget {
  const CommandsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('commands')
          .where('status', whereIn: ['accepted', 'refused'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final commands = snapshot.data!.docs;

        return Column(
          children: commands.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return CommandActivityCard(data: data);
          }).toList(),
        );
      },
    );
  }
}

class CommandActivityCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const CommandActivityCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final driver = data['driver'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardStyle(),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundImage: AssetImage("assets/chauffeur.png"),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(driver?['username'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(driver?['userCode'] ?? '',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 6),
                Text(
                  data['status'] == 'accepted'
                      ? "Commande acceptée ${data['id']}"
                      : "Commande refusée ${data['id']}",
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

//// ================= FORMS CARDS (NEW SECTION) =================

class FormsSectionCards extends StatelessWidget {
  const FormsSectionCards({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('forms')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final docs = snapshot.data!.docs;

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: _cardStyle(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage:
                        AssetImage("assets/chauffeur.png"),
                      ),
                      SizedBox(width: 10),
                      Text("Form Report",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoBlock("Distance", data['distance']),
                      _infoBlock("Carburant", data['carburant']),
                      _infoBlock("Problem", data['probleme']),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    "Commentaire",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['commentaire'] ?? '',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _infoBlock(String title, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value?.toString() ?? '',
            style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

//// ================= STYLE =================

BoxDecoration _cardStyle() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: const [
      BoxShadow(
        color: Colors.black12,
        blurRadius: 6,
        offset: Offset(0, 3),
      )
    ],
  );
}