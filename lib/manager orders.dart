import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CommandsPage extends StatefulWidget {
  const CommandsPage({super.key});

  @override
  State<CommandsPage> createState() => _CommandsPageState();
}

class _CommandsPageState extends State<CommandsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> drivers = [];
  List<Map<String, dynamic>> trucks = [];

  @override
  void initState() {
    super.initState();
    fetchDrivers();
    fetchTrucks();
  }

  Future<void> fetchDrivers() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .get();

    setState(() {
      drivers = snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> fetchTrucks() async {
    final snapshot = await _firestore.collection('trucks').get();

    setState(() {
      trucks = snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('commands')
              .where('status', isEqualTo: 'requested')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final commands = snapshot.data!.docs;

            if (commands.isEmpty) {
              return const Center(
                child: Text("No requested commands"),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: commands.length,
              itemBuilder: (context, index) {
                final data = commands[index];

                return CommandCard(
                  commandId: data['id'] ?? '',
                  from: data['from'] ?? '',
                  product: data['product'] ?? '',
                  quantity: data['quantity'].toString(),
                  drivers: drivers,
                  trucks: trucks,
                  docId: data.id,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class CommandCard extends StatefulWidget {
  final String commandId;
  final String from;
  final String product;
  final String quantity;
  final String docId;
  final List<Map<String, dynamic>> drivers;
  final List<Map<String, dynamic>> trucks;

  const CommandCard({
    super.key,
    required this.commandId,
    required this.from,
    required this.product,
    required this.quantity,
    required this.docId,
    required this.drivers,
    required this.trucks,
  });

  @override
  State<CommandCard> createState() => _CommandCardState();
}

class _CommandCardState extends State<CommandCard> {
  Map<String, dynamic>? selectedDriver;
  Map<String, dynamic>? selectedTruck;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ PRICE CONTROLLER
  final TextEditingController priceController = TextEditingController();

  void acceptCommand() async {
    if (selectedDriver == null ||
        selectedTruck == null ||
        priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Select driver, truck & enter price")),
      );
      return;
    }

    await _firestore.collection('commands').doc(widget.docId).update({
      'status': 'pending',
      'driver': selectedDriver,
      'truck': selectedTruck,
      'price': int.parse(priceController.text), // ✅ INT64
    });
  }

  void refuseCommand() async {
    await _firestore.collection('commands').doc(widget.docId).update({
      'status': 'refused',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        children: [
          /// TOP
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.commandId,
                        style: const TextStyle(color: Colors.grey)),

                    const SizedBox(height: 6),

                    const Text("From",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(widget.from),

                    const SizedBox(height: 6),

                    const Text("Product",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(widget.product),

                    const SizedBox(height: 6),

                    const Text("Quantity",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(widget.quantity),
                  ],
                ),
              ),

              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[300],
                  image: const DecorationImage(
                    image: AssetImage("assets/packaging.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            ],
          ),

          const SizedBox(height: 16),

          /// ✅ PRICE FIELD
          TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration().copyWith(
              hintText: "Enter Price (DZD)",
            ),
          ),

          const SizedBox(height: 10),

          /// DRIVER
          DropdownButtonFormField<Map<String, dynamic>>(
            isExpanded: true,
            hint: const Text("Assign Driver"),
            value: selectedDriver,
            items: widget.drivers.map((driver) {
              return DropdownMenuItem(
                value: driver,
                child: Text(driver['username'] ?? ''),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedDriver = value;
              });
            },
            decoration: _inputDecoration(),
          ),

          const SizedBox(height: 10),

          /// TRUCK
          DropdownButtonFormField<Map<String, dynamic>>(
            isExpanded: true,
            hint: const Text("Assign Truck"),
            value: selectedTruck,
            items: widget.trucks.map((truck) {
              return DropdownMenuItem(
                value: truck,
                child: Text(
                  "${truck['truckId']} - ${truck['truckModel']}",
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedTruck = value;
              });
            },
            decoration: _inputDecoration(),
          ),

          const SizedBox(height: 16),

          /// BUTTONS
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[200],
                  ),
                  onPressed: refuseCommand,
                  child: const Text("Refuse"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[300],
                  ),
                  onPressed: acceptCommand,
                  child: const Text("Accept"),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}