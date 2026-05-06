import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriversPage extends StatelessWidget {
  const DriversPage({super.key});

  /// ✅ SAFE LOCATION PARSER
  String parseLocation(dynamic location) {
    if (location is String) return location;

    if (location is Map<String, dynamic>) {
      final lat = location['lat'] ?? '';
      final lng = location['lng'] ?? '';
      return "$lat, $lng";
    }

    return "Offline";
  }

  /// ✅ SAFE INT PARSER
  int parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'driver')
              .snapshots(),
          builder: (context, snapshot) {
            /// ✅ HANDLE ERROR (VERY IMPORTANT)
            if (snapshot.hasError) {
              return Center(
                child: Text("Error: ${snapshot.error}"),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final drivers = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: drivers.length,
              itemBuilder: (context, index) {
                final driver = drivers[index];

                final rawData = driver.data();

                /// ✅ SAFE CAST (PREVENT CRASH)
                if (rawData == null || rawData is! Map<String, dynamic>) {
                  return const SizedBox();
                }

                final data = rawData;

                return DriverCard(
                  driverId: driver.id,
                  username: data['username']?.toString() ?? '',
                  userCode: data['userCode']?.toString() ?? '',
                  deliveries: parseInt(data['deliveries']),
                  status: data['status']?.toString() ?? 'Idle',
                  location: parseLocation(data['location']),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _loadTruck();
  }

  /// ✅ SAFE FIRESTORE QUERY
  Future<void> _loadTruck() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('commands')
          .where('driver.uid', isEqualTo: widget.driverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (snapshot.docs.isNotEmpty) {
        final rawData = snapshot.docs.first.data();

        if (rawData is! Map<String, dynamic>) return;

        final truckField = rawData['truck'];

        String result = "Unknown";

        if (truckField is Map<String, dynamic>) {
          result =
              truckField['truckModel'] ??
                  truckField['name'] ??
                  "Unknown";
        } else if (truckField is String) {
          result = truckField;
        }

        /// ✅ PREVENT setState AFTER DISPOSE
        if (mounted) {
          setState(() {
            truck = result;
          });
        }
      }
    } catch (e) {
      debugPrint("Truck load error: $e");
    }
  }

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
          )
        ],
      ),
      child: Column(
        children: [
          /// TOP CONTENT
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// LEFT INFO
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.username,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),

                    Text(widget.userCode,
                        style: const TextStyle(color: Colors.grey)),

                    const SizedBox(height: 10),

                    const Text("Status"),
                    Text(
                      widget.status,
                      style: TextStyle(
                        color: getStatusColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text("Location"),
                    Text(widget.location),

                    const SizedBox(height: 10),

                    const Text("Truck"),
                    Text(truck),

                    const SizedBox(height: 10),

                    const Text("Deliveries"),
                    Text(widget.deliveries.toString()),
                  ],
                ),
              ),

              /// ✅ SAFE IMAGE (NO CRASH IF MISSING)
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                  image: const DecorationImage(
                    image: AssetImage("assets/chauffeur.png"),
                    fit: BoxFit.cover,
                    onError: null, // prevents crash
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          /// MINI CHART
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(show: false),
                barGroups: [
                  _barGroup(10, 90, 50, 40),
                  _barGroup(20, 80, 70, 65),
                  _barGroup(30, 60, 40, 55),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          /// LEGEND
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: Colors.blue, text: "01/26"),
              SizedBox(width: 10),
              _Legend(color: Colors.red, text: "02/26"),
              SizedBox(width: 10),
              _Legend(color: Colors.teal, text: "03/26"),
            ],
          )
        ],
      ),
    );
  }

  BarChartGroupData _barGroup(double x, double y1, double y2, double y3) {
    return BarChartGroupData(
      x: x.toInt(),
      barRods: [
        BarChartRodData(toY: y1, color: Colors.blue, width: 4),
        BarChartRodData(toY: y2, color: Colors.red, width: 4),
        BarChartRodData(toY: y3, color: Colors.teal, width: 4),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;

  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}