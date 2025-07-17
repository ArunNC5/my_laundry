import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';

class PickupScreen extends StatefulWidget {
  const PickupScreen({super.key});

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  final SupabaseService supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController agentController = TextEditingController();
  List<Map<String, dynamic>> clothes = [];
  bool isSubmitting = false;

  void addClothingItem() {
    setState(() {
      clothes.add({'item_type': '', 'quantity': 1});
    });
  }

  Future<void> submitPickup() async {
    if (!_formKey.currentState!.validate() || clothes.isEmpty) return;
    setState(() => isSubmitting = true);

    try {
      final orderId = await supabaseService.insertOrder(
        customerName: nameController.text.trim(),
        customerPhone: phoneController.text.trim(),
        customerAddress: addressController.text.trim(),
        agentName: agentController.text.trim(),
        status: 'picked_up',
        pickupTime: DateTime.now(),
        deliveryDueTime: DateTime.now().add(const Duration(hours: 36)),
      );

      for (var item in clothes) {
        await supabaseService.insertOrderItem(
          orderId: orderId,
          itemType: item['item_type'],
          quantity: item['quantity'],
        );
      }

      await supabaseService.insertStatusUpdate(
        orderId: orderId,
        newStatus: 'picked_up',
        updatedBy: 'agent',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pickup successfully created!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  InputDecoration inputDecoration(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text(
          'New Pickup',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: nameController,
                decoration: inputDecoration('Customer Name'),
                validator: (v) => v!.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                decoration: inputDecoration('Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Enter phone' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressController,
                decoration: inputDecoration('Address'),
                validator: (v) => v!.isEmpty ? 'Enter address' : null,
              ),
              // const SizedBox(height: 12),
              // TextFormField(
              //   controller: agentController,
              //   decoration: inputDecoration('Agent Name (optional)'),
              // ),
              const SizedBox(height: 20),
              Row(
                children: const [
                  Text('Clothes List', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              ...clothes.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: item['item_type'],
                            onChanged: (val) => item['item_type'] = val,
                            decoration: const InputDecoration(hintText: 'Item Type'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 60,
                          child: TextFormField(
                            initialValue: item['quantity'].toString(),
                            onChanged: (val) =>
                            item['quantity'] = int.tryParse(val) ?? 1,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: 'Qty'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => setState(() => clothes.removeAt(index)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              TextButton.icon(
                icon: const Icon(Icons.add_circle_outline),
                label: const Text("Add Item"),
                onPressed: addClothingItem,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: isSubmitting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.done),
                  label: Text(
                    isSubmitting ? 'Submitting...' : 'Submit & Pickup',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: const Color(0xFF6A11CB),
                  ),
                  onPressed: isSubmitting ? null : submitPickup,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
