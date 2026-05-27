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
            _SectionHeader(
              icon: Icons.assignment_outlined,
              label: "Driver Requests",
              color: Colors.orange,
            ),
            SizedBox(height: 10),
            FormsSection(),
            SizedBox(height: 20),
            _SectionHeader(
              icon: Icons.local_shipping_outlined,
              label: "Order Activity",
              color: Colors.blue,
            ),
            SizedBox(height: 10),
            CommandsSection(),
            SizedBox(height: 20),
            _SectionHeader(
              icon: Icons.description_outlined,
              label: "Form Reports",
              color: Colors.teal,
            ),
            SizedBox(height: 10),
            FormsSectionCards(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

//// ================= SECTION HEADER =================

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

//// ================= DEMAND =================

class FormsSection extends StatelessWidget {
  const FormsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // No status filter — we hide accepted/refused locally after action
      stream: FirebaseFirestore.instance
          .collection('demand')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }
        if (snapshot.hasError) {
          return const _EmptyCard(
            icon: Icons.error_outline,
            message: "Failed to load requests",
            color: Colors.red,
          );
        }

        // Only show docs whose status is NOT accepted or refused
        final forms = (snapshot.data?.docs ?? []).where((doc) {
          final status =
              (doc.data() as Map<String, dynamic>)['status']?.toString() ?? '';
          return status != 'accepted' && status != 'refused';
        }).toList();

        if (forms.isEmpty) {
          return const _EmptyCard(
            icon: Icons.inbox_outlined,
            message: "No pending driver requests",
            color: Colors.orange,
          );
        }

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

class FormCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;

  const FormCard({super.key, required this.data, required this.docId});

  @override
  State<FormCard> createState() => _FormCardState();
}

class _FormCardState extends State<FormCard> {
  bool _loading = false;

  String _formatTimestamp(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) {
      final dt = value.toDate();
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      final y = dt.year;
      final h = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '$d/$mo/$y  $h:$mi';
    }
    return value.toString();
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('demand')
          .doc(widget.docId)
          .update({'status': status});
      // The stream re-emits and the where() filter hides this card automatically
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatTimestamp(widget.data['createdAt']);
    final driverId = widget.data['driverId']?.toString() ?? '';
    final demande = widget.data['demande']?.toString() ?? '';
    final duree = widget.data['duree']?.toString() ?? '';
    final raison = widget.data['raison']?.toString() ?? '';
    final document = widget.data['document']?.toString() ?? '';
    final status = widget.data['status']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _cardStyle(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Coloured top bar ─────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3E0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundImage: AssetImage("assets/chauffeur.png"),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Driver Request",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (status.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timestamp + Driver ID
                Row(
                  children: [
                    if (createdAt.isNotEmpty) ...[
                      Icon(Icons.access_time,
                          size: 13, color: Colors.blue[400]),
                      const SizedBox(width: 4),
                      Text(
                        createdAt,
                        style: TextStyle(
                            fontSize: 12, color: Colors.blue[600]),
                      ),
                    ],
                    const Spacer(),
                    if (driverId.isNotEmpty) ...[
                      Icon(Icons.badge_outlined,
                          size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          driverId,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Three info blocks
                Row(
                  children: [
                    Expanded(child: _infoBlock("Demande", demande)),
                    Container(
                        width: 1, height: 36, color: Colors.grey[200]),
                    Expanded(
                        child:
                        _infoBlock("Durée", duree, center: true)),
                    Container(
                        width: 1, height: 36, color: Colors.grey[200]),
                    Expanded(
                        child:
                        _infoBlock("Raison", raison, right: true)),
                  ],
                ),

                const SizedBox(height: 14),

                // Document row
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file_outlined,
                          size: 18, color: Colors.blueGrey[400]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          document.isEmpty ? 'No document' : document,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: document.isEmpty
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                      ),
                      if (document.isNotEmpty)
                        Icon(Icons.download_outlined,
                            size: 20, color: Colors.blue[400]),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Action buttons
                _loading
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(),
                  ),
                )
                    : Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus("refused"),
                        icon: const Icon(Icons.close, size: 15),
                        label: const Text("Refuse"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[50],
                          foregroundColor: Colors.red[800],
                          elevation: 0,
                          side: BorderSide(
                              color: Colors.red.shade200),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus("accepted"),
                        icon: const Icon(Icons.check, size: 15),
                        label: const Text("Accept"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBlock(String title, String value,
      {bool center = false, bool right = false}) {
    final align = right
        ? CrossAxisAlignment.end
        : (center ? CrossAxisAlignment.center : CrossAxisAlignment.start);
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500]),
        ),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? '—' : value,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
        ),
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
          .where('status', whereIn: ['accepted', 'refused']).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }
        if (snapshot.hasError) {
          return const _EmptyCard(
            icon: Icons.error_outline,
            message: "Failed to load orders",
            color: Colors.red,
          );
        }

        final commands = snapshot.data?.docs ?? [];

        if (commands.isEmpty) {
          return const _EmptyCard(
            icon: Icons.local_shipping_outlined,
            message: "No accepted or refused orders yet",
            color: Colors.blue,
          );
        }

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
    final driverName =
        driver?['username']?.toString() ?? 'Unknown Driver';
    final driverCode = driver?['userCode']?.toString() ?? '';
    final orderId = data['id']?.toString() ?? '';
    final isAccepted = data['status'] == 'accepted';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: _cardStyle(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isAccepted ? Colors.green[50] : Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAccepted
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
              color: isAccepted ? Colors.green[700] : Colors.red[700],
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black87),
                    children: [
                      const TextSpan(
                        text: 'Driver ',
                        style: TextStyle(color: Colors.grey),
                      ),
                      TextSpan(
                        text: driverName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: isAccepted
                            ? ' has accepted'
                            : ' has refused',
                        style: TextStyle(
                          color: isAccepted
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: ' the order '),
                      TextSpan(
                        text: '#$orderId',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (driverCode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    driverCode,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
              isAccepted ? Colors.green[100] : Colors.red[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isAccepted ? 'Accepted' : 'Refused',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isAccepted
                    ? Colors.green[800]
                    : Colors.red[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//// ================= FORMS CARDS =================

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }
        if (snapshot.hasError) {
          return const _EmptyCard(
            icon: Icons.error_outline,
            message: "Failed to load form reports",
            color: Colors.red,
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const _EmptyCard(
            icon: Icons.description_outlined,
            message: "No form reports yet",
            color: Colors.teal,
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _FormReportCard(data: data);
          }).toList(),
        );
      },
    );
  }
}

class _FormReportCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _FormReportCard({required this.data});

  Widget _infoBlock(String title, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(
          value?.toString().isEmpty ?? true ? '—' : value.toString(),
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _cardStyle(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2F1),
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(18)),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: AssetImage("assets/chauffeur.png"),
                ),
                SizedBox(width: 10),
                Text(
                  "Form Report",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _infoBlock("Distance", data['distance'])),
                    Container(
                        width: 1, height: 36, color: Colors.grey[200]),
                    Expanded(
                        child:
                        _infoBlock("Carburant", data['carburant'])),
                    Container(
                        width: 1, height: 36, color: Colors.grey[200]),
                    Expanded(
                        child: _infoBlock("Problem", data['probleme'])),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text("Commentaire",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500])),
                const SizedBox(height: 4),
                Text(
                  data['commentaire']?.toString().isEmpty ?? true
                      ? '—'
                      : data['commentaire'].toString(),
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//// ================= SHARED WIDGETS =================

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(24),
      decoration: _cardStyle(),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _EmptyCard({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: _cardStyle(),
      child: Row(
        children: [
          Icon(icon, color: color.withOpacity(0.45), size: 28),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
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
      ),
    ],
  );
}