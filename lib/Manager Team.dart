import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerDriversPage extends StatefulWidget {
  const ManagerDriversPage({super.key});

  @override
  State<ManagerDriversPage> createState() => _ManagerDriversPageState();
}

class _ManagerDriversPageState extends State<ManagerDriversPage> {
  final Color primaryColor =  Colors.white;
  final TextEditingController searchController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔹 Add driver to manager's fleet using unique code
  Future<void> addDriverByCode() async {
    String code = searchController.text.trim();

    if (code.isEmpty) return;

    try {
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('userCode', isEqualTo: code)
          .where('role', isEqualTo: 'driver')
          .get();

      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Driver not found")),
        );
        return;
      }

      var driverDoc = userQuery.docs.first;

      await _firestore
          .collection('manager_drivers')
          .doc(driverDoc.id)
          .set({
        'uid': driverDoc.id,
        'name': driverDoc['username'],
        'code': driverDoc['userCode'],
        'truck': '',
        'active': true,
        'addedAt': Timestamp.now(),
      });

      searchController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Driver added successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error adding driver")),
      );
    }
  }

  /// 🔹 Assign truck
  Future<void> assignTruck(String uid) async {
    TextEditingController truckController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Assign Truck"),
        content: TextField(
          controller: truckController,
          decoration: const InputDecoration(
            labelText: "Truck ID",
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () async {
              await _firestore
                  .collection('manager_drivers')
                  .doc(uid)
                  .update({
                'truck': truckController.text.trim(),
              });

              Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  /// 🔹 Remove driver
  Future<void> removeDriver(String uid) async {
    await _firestore.collection('manager_drivers').doc(uid).delete();
  }

  /// 🔹 Toggle active/inactive
  Future<void> toggleStatus(String uid, bool currentStatus) async {
    await _firestore.collection('manager_drivers').doc(uid).update({
      'active': !currentStatus,
    });
  }

  /// 🔹 Assign a shipment to the driver
  Future<void> assignShipment(String driverUid) async {
    final TextEditingController customerController = TextEditingController();
    final TextEditingController fromController = TextEditingController();
    final TextEditingController toController = TextEditingController();
    final TextEditingController trackingController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Assign Shipment"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: customerController,
                  decoration: const InputDecoration(labelText: "Customer"),
                ),
                TextField(
                  controller: fromController,
                  decoration: const InputDecoration(labelText: "From"),
                ),
                TextField(
                  controller: toController,
                  decoration: const InputDecoration(labelText: "To"),
                ),
                TextField(
                  controller: trackingController,
                  decoration: const InputDecoration(labelText: "Tracking Number"),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text("Arrival Date: "),
                    TextButton(
                      onPressed: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Text(selectedDate == null
                          ? "Select Date"
                          : "${selectedDate!.toLocal()}".split(' ')[0]),
                    )
                  ],
                )
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.white))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: () async {
                if (customerController.text.isEmpty ||
                    fromController.text.isEmpty ||
                    toController.text.isEmpty ||
                    trackingController.text.isEmpty ||
                    selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Fill all fields")),
                  );
                  return;
                }

                await _firestore.collection('shipments').add({
                  'driverUid': driverUid,
                  'customer': customerController.text.trim(),
                  'from': fromController.text.trim(),
                  'to': toController.text.trim(),
                  'trackingNumber': trackingController.text.trim(),
                  'arrivalDate': "${selectedDate!.toLocal()}".split(' ')[0], // String
                  'status': "Pending",
                  'assignedAt': DateTime.now().toString(), // String
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Shipment assigned")),
                );
              },
              child: const Text("Assign", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// 🔹 Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white70),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: "Enter driver unique code",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: primaryColor),
                    onPressed: addDriverByCode,
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            /// 🔹 Drivers List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('manager_drivers').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No drivers added yet"));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var driver = snapshot.data!.docs[index];
                      bool isActive = driver['active'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Color(0xFF97B2D1),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: primaryColor.withOpacity(0.1),
                                  child: Icon(Icons.person, color: primaryColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    driver['name'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                                Switch(
                                  value: isActive,
                                  activeColor: primaryColor,
                                  onChanged: (_) =>
                                      toggleStatus(driver.id, isActive),
                                )
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text("Code: ${driver['code']}",
                                style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 6),
                            Text(
                                "Truck: ${driver['truck'].isEmpty ? "Not Assigned" : driver['truck']}",
                                style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.local_shipping,
                                      color: primaryColor),
                                  onPressed: () => assignTruck(driver.id),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.assignment,
                                      color: Colors.white),
                                  onPressed: () =>
                                      assignShipment(driver.id),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => removeDriver(driver.id),
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}