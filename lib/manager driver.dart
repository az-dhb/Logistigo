import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriversPage extends StatefulWidget {
  const DriversPage({super.key});

  @override
  State<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends State<DriversPage> {
  final List<String> _addedDriverDocIds = [];
  final TextEditingController _idController = TextEditingController();

  String get _managerUid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_managerUid)
          .get();
      final data = doc.data();
      if (data != null && data['drivers'] is List) {
        final List<String> saved = List<String>.from(data['drivers'] as List);
        if (mounted) {
          setState(() => _addedDriverDocIds
            ..clear()
            ..addAll(saved));
        }
      }
    } catch (e) {
      debugPrint("Error loading drivers: $e");
    }
  }

  Future<void> _addDriverToFirestore(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_managerUid)
        .set(
      {'drivers': FieldValue.arrayUnion([docId])},
      SetOptions(merge: true),
    );
  }

  Future<void> _removeDriverFromFirestore(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_managerUid)
        .update({'drivers': FieldValue.arrayRemove([docId])});
  }

  String parseLocation(dynamic location) {
    if (location is String) return location;
    if (location is Map<String, dynamic>) {
      final lat = location['lat'] ?? '';
      final lng = location['lng'] ?? '';
      return "$lat, $lng";
    }
    return "Offline";
  }

  int parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Future<void> _showAddDriverDialog() async {
    _idController.clear();
    String? errorText;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "Add Driver by UID",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _idController,
                    decoration: InputDecoration(
                      hintText: "Enter driver UID",
                      errorText: errorText,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                    final uid = _idController.text.trim();
                    if (uid.isEmpty) {
                      setDialogState(
                              () => errorText = "UID cannot be empty");
                      return;
                    }
                    setDialogState(() {
                      isLoading = true;
                      errorText = null;
                    });
                    try {
                      final query = await FirebaseFirestore.instance
                          .collection('users')
                          .where('uid', isEqualTo: uid)
                          .limit(1)
                          .get();

                      if (query.docs.isEmpty) {
                        setDialogState(() {
                          errorText = "No user found with this UID";
                          isLoading = false;
                        });
                        return;
                      }

                      final doc = query.docs.first;
                      final data = doc.data();

                      if (data['role']?.toString() != 'driver') {
                        setDialogState(() {
                          errorText = "User is not a driver";
                          isLoading = false;
                        });
                        return;
                      }

                      if (_addedDriverDocIds.contains(doc.id)) {
                        setDialogState(() {
                          errorText = "Driver already added";
                          isLoading = false;
                        });
                        return;
                      }

                      setState(() => _addedDriverDocIds.add(doc.id));
                      await _addDriverToFirestore(doc.id);

                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      setDialogState(() {
                        errorText = "Error: $e";
                        isLoading = false;
                      });
                    }
                  },
                  child: isLoading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: _addedDriverDocIds.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search, size: 72, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text("No drivers added yet",
                  style: TextStyle(fontSize: 16, color: Colors.grey[500])),
              const SizedBox(height: 8),
              Text("Tap + to add a driver by UID",
                  style: TextStyle(fontSize: 13, color: Colors.grey[400])),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.only(
              left: 16, right: 16, top: 16, bottom: 90),
          itemCount: _addedDriverDocIds.length,
          itemBuilder: (context, index) {
            final docId = _addedDriverDocIds[index];

            // ✅ StreamBuilder on the user doc so card info also live-updates
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(docId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!snapshot.data!.exists) return const SizedBox();

                final data =
                snapshot.data!.data() as Map<String, dynamic>;

                return Stack(
                  children: [
                    DriverCard(
                      driverId: docId,
                      username: data['username']?.toString() ?? '',
                      userCode: data['userCode']?.toString() ?? '',
                      deliveries: parseInt(data['deliveries']),
                      status: data['status']?.toString() ?? 'Idle',
                      location: parseLocation(data['location']),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () async {
                          setState(() => _addedDriverDocIds.removeAt(index));
                          await _removeDriverFromFirestore(docId);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close,
                              size: 16, color: Colors.red[700]),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDriverDialog,
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text("Add Driver"),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class MonthStats {
  final String label;
  final int pending;
  final int done;
  final int refused;

  const MonthStats({
    required this.label,
    required this.pending,
    required this.done,
    required this.refused,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DriverCard — chart powered by StreamBuilder, updates in real time
// ─────────────────────────────────────────────────────────────────────────────

class DriverCard extends StatefulWidget {
  final String driverId;
  final String username;
  final String userCode;
  final int deliveries;
  final String status;
  final String location;

  const DriverCard({
    super.key,
    required this.driverId,
    required this.username,
    required this.userCode,
    required this.deliveries,
    required this.status,
    required this.location,
  });

  @override
  State<DriverCard> createState() => _DriverCardState();
}

class _DriverCardState extends State<DriverCard> {
  String truck = "Not Assigned";

  // ── Month helpers ──────────────────────────────────────────────────────────

  List<Map<String, int>> _last3Months() {
    final now = DateTime.now();
    return List.generate(3, (i) {
      int month = now.month - 2 + i;
      int year = now.year;
      if (month <= 0) {
        month += 12;
        year -= 1;
      }
      return {'year': year, 'month': month};
    });
  }

  String _monthLabel(int year, int month) {
    final mm = month.toString().padLeft(2, '0');
    final yy = (year % 100).toString().padLeft(2, '0');
    return "$mm/$yy";
  }

  /// Converts a live Firestore snapshot into [MonthStats] list — pure & sync.
  List<MonthStats> _buildStats(List<QueryDocumentSnapshot> docs) {
    final months = _last3Months();

    final Map<String, Map<String, int>> counts = {
      for (final m in months)
        _monthLabel(m['year']!, m['month']!): {
          'pending': 0,
          'done': 0,
          'refused': 0,
        }
    };

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString().toLowerCase();

      DateTime? date;
      final ts = data['createdAt'] ?? data['timestamp'] ?? data['date'];
      if (ts is Timestamp) date = ts.toDate();
      if (date == null) continue;

      final label = _monthLabel(date.year, date.month);
      if (!counts.containsKey(label)) continue;

      if (status == 'pending') {
        counts[label]!['pending'] = counts[label]!['pending']! + 1;
      } else if (status == 'arrived' || status == 'done' || status == 'delivered') {
        counts[label]!['done'] = counts[label]!['done']! + 1;
      } else if (status == 'refused' || status == 'canceled') {
        counts[label]!['refused'] = counts[label]!['refused']! + 1;
      }
    }

    return months.map((m) {
      final label = _monthLabel(m['year']!, m['month']!);
      final c = counts[label]!;
      return MonthStats(
        label: label,
        pending: c['pending']!,
        done: c['done']!,
        refused: c['refused']!,
      );
    }).toList();
  }

  // ── Truck ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadTruck();
  }

  Future<void> _loadTruck() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('commands')
          .where('driver.uid', isEqualTo: widget.driverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (snapshot.docs.isNotEmpty) {
        final rawData = snapshot.docs.first.data();
        final truckField = rawData['truck'];
        String result = "Unknown";
        if (truckField is Map<String, dynamic>) {
          result = truckField['truckModel'] ?? truckField['name'] ?? "Unknown";
        } else if (truckField is String) {
          result = truckField;
        }
        if (mounted) setState(() => truck = result);
      }
    } catch (e) {
      debugPrint("Truck load error: $e");
    }
  }

  // ── Chart helpers ──────────────────────────────────────────────────────────

  Color getStatusColor() {
    switch (widget.status.toLowerCase()) {
      case "delivering":
        return Colors.orange;
      case "congé":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  double _maxY(List<MonthStats> stats) {
    if (stats.isEmpty) return 5;
    final max = stats
        .expand((m) => [
      m.pending.toDouble(),
      m.done.toDouble(),
      m.refused.toDouble()
    ])
        .reduce((a, b) => a > b ? a : b);
    return (max < 5) ? 5 : (max * 1.3).ceilToDouble();
  }

  BarChartGroupData _barGroup(int x, MonthStats stats) {
    return BarChartGroupData(
      x: x,
      barsSpace: 4,
      barRods: [
        BarChartRodData(
          toY: stats.pending.toDouble(),
          color: Colors.blue,
          width: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        BarChartRodData(
          toY: stats.done.toDouble(),
          color: Colors.teal,
          width: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        BarChartRodData(
          toY: stats.refused.toDouble(),
          color: Colors.red,
          width: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top row ────────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.username,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(widget.userCode,
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    const Text("Status",
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(widget.status,
                        style: TextStyle(
                            color: getStatusColor(),
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text("Location",
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(widget.location),
                    const SizedBox(height: 10),
                    const Text("Truck",
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(truck),
                    const SizedBox(height: 10),
                    const Text("Deliveries",
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(widget.deliveries.toString()),
                  ],
                ),
              ),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                  image: const DecorationImage(
                    image: AssetImage("assets/chauffeur.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Chart — live via StreamBuilder ─────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('commands')
                .where('driver.uid', isEqualTo: widget.driverId)
                .snapshots(), // ✅ real-time listener
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final monthStats = _buildStats(snapshot.data!.docs);
              final maxY = _maxY(monthStats);

              return SizedBox(
                height: 140,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (maxY / 4).ceilToDouble(),
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: (maxY / 4).ceilToDouble(),
                          reservedSize: 28,
                          getTitlesWidget: (value, _) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) {
                            final i = value.toInt();
                            if (i < 0 || i >= monthStats.length) {
                              return const SizedBox();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                monthStats[i].label,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    barGroups: List.generate(
                      monthStats.length,
                          (i) => _barGroup(i, monthStats[i]),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          const labels = ['Pending', 'Done', 'Refused'];
                          return BarTooltipItem(
                            '${monthStats[groupIndex].label}\n'
                                '${labels[rodIndex]}: ${rod.toY.toInt()}',
                            const TextStyle(
                                color: Colors.white, fontSize: 11),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // ── Legend ─────────────────────────────────────────────────────────
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: Colors.blue, text: "Pending"),
              SizedBox(width: 10),
              _Legend(color: Colors.teal, text: "Done"),
              SizedBox(width: 10),
              _Legend(color: Colors.red, text: "Refused"),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final Color color;
  final String text;

  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}