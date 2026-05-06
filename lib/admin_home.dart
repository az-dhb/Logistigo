import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logistigo/Login.dart';
import 'package:logistigo/driver update.dart';
import 'package:logistigo/manager driver.dart';
import 'package:logistigo/manager notification.dart';
import 'package:logistigo/manager orders.dart';
import 'package:logistigo/manager truck.dart';

class ManagerDashboardPage extends StatefulWidget {
  const ManagerDashboardPage({super.key});

  @override
  State<ManagerDashboardPage> createState() =>
      _ManagerDashboardPageState();
}

class _ManagerDashboardPageState
    extends State<ManagerDashboardPage> {
  String userName = "User";
  String email = "";

  int totalCommands = 0;
  int pendingCommands = 0;
  int completedCommands = 0;

  List<FlSpot> chartData = [];

  int _selectedIndex = 0;

  final Color primaryColor = const Color(0xFF97B2D1);

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadCommandsData();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      email = user.email ?? "";

      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        userName = doc["username"] ?? "User";
      }
      setState(() {});
    }
  }

  Future<void> _loadCommandsData() async {
    final snapshot =
    await FirebaseFirestore.instance.collection("commands").get();

    int total = snapshot.docs.length;
    int pending = 0;
    int completed = 0;

    Map<int, int> dailyCounts = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();

      String status = data["status"] ?? "pending";

      if (status == "pending") pending++;
      if (status == "completed") completed++;

      Timestamp? timestamp = data["timestamp"];
      if (timestamp != null) {
        int day = timestamp.toDate().day;
        dailyCounts[day] = (dailyCounts[day] ?? 0) + 1;
      }
    }

    List<FlSpot> spots = dailyCounts.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    setState(() {
      totalCommands = total;
      pendingCommands = pending;
      completedCommands = completed;
      chartData = spots;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => LoginPage(),
      ),
    );
  }

  void _showAddProductDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Product"),
          content: TextField(
            controller: controller,
            decoration:
            const InputDecoration(hintText: "Product name"),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            TextButton(
              onPressed: () async {
                final uid =
                    FirebaseAuth.instance.currentUser!.uid;
                final product = controller.text.trim();

                if (product.isEmpty) return;

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({
                  "products": FieldValue.arrayUnion([product])
                });

                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  Widget _dashboardBody() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Welcome Back",
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 5),
                    Text("Hi, $userName!",
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(email,
                        style:
                        const TextStyle(color: Colors.grey)),
                  ],
                ),

                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  color: Colors.black,
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          const Text("Commands Chart",
              style:
              TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

          const SizedBox(height: 10),

          Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: chartData,
                    isCurved: true,
                    barWidth: 4,
                    color: primaryColor,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          _buildStatCard("Total Commands", totalCommands),
          _buildStatCard("Pending Commands", pendingCommands),
          _buildStatCard("Complete Commands", completedCommands),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _dashboardBody(),
      DriversPage(),
      TrucksPage(),
      CommandsPage(),
      NotificationsPage(),
    ];

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      extendBody: true,
      body: SafeArea(child: pages[_selectedIndex]),

      /// 🔥 FIXED FLOATING NAVBAR
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: bottomPadding + 12,
        ),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(Icons.dashboard, 0),
              _buildNavItem(Icons.badge, 1),
              _buildNavItem(Icons.local_shipping, 2),
              _buildNavItem(Icons.inventory, 3),
              _buildNavItem(Icons.notifications, 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 24,
          color: isSelected ? Colors.white : Colors.grey,
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _buildStatCard(String title, int value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          Text(value.toString(),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}