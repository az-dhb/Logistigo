import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrucksPage extends StatelessWidget {
  const TrucksPage({super.key});

  void _showAddTruckDialog(BuildContext context) {
    final modelController = TextEditingController();
    final idController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          // ← This is the key fix: reads viewInsets inside the sheet's own context
          padding: MediaQuery.of(context).viewInsets,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const Text(
                  "Add Truck",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                // Truck Model
                TextField(
                  controller: modelController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: "Truck Model",
                    prefixIcon: const Icon(Icons.local_shipping_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Truck ID
                TextField(
                  controller: idController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: "Truck ID",
                    prefixIcon: const Icon(Icons.tag_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (modelController.text.trim().isEmpty ||
                          idController.text.trim().isEmpty) return;

                      await FirebaseFirestore.instance
                          .collection('trucks')
                          .add({
                        "truckModel": modelController.text.trim(),
                        "truckId": idController.text.trim(),
                        "deliveries": 0,
                      });

                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      "Add Truck",
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream:
          FirebaseFirestore.instance.collection('trucks').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final trucks = snapshot.data!.docs;

            if (trucks.isEmpty) {
              return const Center(
                child: Text(
                  "No trucks yet.\nTap + to add one.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trucks.length,
              itemBuilder: (context, index) {
                final data =
                trucks[index].data() as Map<String, dynamic>;
                return TruckCard(
                  truckId: data['truckId']?.toString() ?? '',
                  truckModel: data['truckModel']?.toString() ?? '',
                  deliveries: data['deliveries'] ?? 0,
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTruckDialog(context),
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class TruckCard extends StatefulWidget {
  final String truckId;
  final String truckModel;
  final int deliveries;

  const TruckCard({
    super.key,
    required this.truckId,
    required this.truckModel,
    required this.deliveries,
  });

  @override
  State<TruckCard> createState() => _TruckCardState();
}

class _TruckCardState extends State<TruckCard> {
  String status = "Parked";
  String location = "Garage";

  List<BarChartGroupData> deliveriesChart = [];
  List<FlSpot> fuelChart1 = [];
  List<FlSpot> fuelChart2 = [];
  List<FlSpot> fuelChart3 = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final commandsSnap = await FirebaseFirestore.instance
        .collection('commands')
        .where('truck', isEqualTo: widget.truckId)
        .get();

    Map<int, int> monthCounts = {};
    List<double> fuelValues = [];

    for (var doc in commandsSnap.docs) {
      final data = doc.data();

      if (data['status'] == 'pending') {
        status = "In Mission";
        location = "On Route";
      }

      Timestamp? date = data['date'];
      if (date != null) {
        int day = date.toDate().day;
        monthCounts[day] = (monthCounts[day] ?? 0) + 1;
      }

      final formSnap = await FirebaseFirestore.instance
          .collection('forms')
          .where('commandId', isEqualTo: data['commandId'])
          .get();

      for (var f in formSnap.docs) {
        fuelValues.add((f['carburant'] ?? 0).toDouble());
      }
    }

    deliveriesChart = monthCounts.entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(toY: e.value.toDouble(), width: 6),
        ],
      );
    }).toList();

    for (int i = 0; i < fuelValues.length; i++) {
      double x = i.toDouble();
      fuelChart1.add(FlSpot(x, fuelValues[i]));
      fuelChart2.add(FlSpot(x, fuelValues[i] * 0.9));
      fuelChart3.add(FlSpot(x, fuelValues[i] * 1.1));
    }

    if (mounted) setState(() {});
  }

  Color getStatusColor() {
    return status == "In Mission" ? Colors.orange : Colors.green;
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
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.truckModel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.truckId,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    const Text("Status",
                        style:
                        TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(
                      status,
                      style: TextStyle(
                        color: getStatusColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text("Location",
                        style:
                        TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(location),
                    const SizedBox(height: 10),
                    const Text("Deliveries",
                        style:
                        TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(widget.deliveries.toString()),
                  ],
                ),
              ),
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage("assets/truck.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Deliveries bar chart
          SizedBox(
            height: 120,
            child: deliveriesChart.isEmpty
                ? const Center(
              child: Text("No delivery data",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
                : BarChart(
              BarChartData(
                gridData: const FlGridData(show: true),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: deliveriesChart,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Fuel line chart
          SizedBox(
            height: 150,
            child: fuelChart1.isEmpty
                ? const Center(
              child: Text("No fuel data",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
                : LineChart(
              LineChartData(
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [
                  _line(fuelChart1, Colors.blue),
                  _line(fuelChart2, Colors.red),
                  _line(fuelChart3, Colors.teal),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> data, Color color) {
    return LineChartBarData(
      spots: data,
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: false),
    );
  }
}