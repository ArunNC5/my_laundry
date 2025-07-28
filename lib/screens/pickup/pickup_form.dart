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
  final TextEditingController customItemController = TextEditingController();

  List<Map<String, dynamic>> clothes = [];
  bool isSubmitting = false;

  final List<Map<String, dynamic>> itemTypes = [
    {"label": "Shirt", "iconPath": "assets/icons/shirt.png"},
    {"label": "T-Shirt", "iconPath": "assets/icons/tshirt.png"},
    {"label": "Pant", "iconPath": "assets/icons/trousers.png"},
    {"label": "Saree", "iconPath": "assets/icons/saree.png"},
    {"label": "Blouse", "iconPath": "assets/icons/blouse.png"},
    {"label": "Dhoti", "iconPath": "assets/icons/dhoti.png"},
    {"label": "Kids Wear", "iconPath": "assets/icons/baby-clothes.png"},
    {"label": "Blanket", "iconPath": "assets/icons/blanket.png"},
    {"label": "Tops", "iconPath": "assets/icons/tshirt.png"},
    {"label": "Bottom", "iconPath": "assets/icons/garment.png"},
    {"label": "Towel", "iconPath": "assets/icons/towel.png"},
    {"label": "Bedsheet", "iconPath": "assets/icons/sheet.png"},
    {"label": "Custom", "iconPath": "assets/icons/basket.png"},
  ];

  void addClothingItem(String itemType) {
    setState(() {
      clothes.add({'item_type': itemType, 'quantity': 1});
    });
  }

  Future<void> fetchAndPrefillCustomer(String phone) async {
    if (phone.length < 10) return;
    final existingCustomer = await supabaseService.fetchLatestCustomerByPhone(
      phone,
    );
    print('Fetched customer: $existingCustomer');

    if (existingCustomer != null) {
      nameController.text = existingCustomer['customer_name'] ?? '';
      addressController.text = existingCustomer['customer_address'] ?? '';
    }
  }

  Future<void> submitPickup() async {
    if (!_formKey.currentState!.validate() || clothes.isEmpty) return;
    setState(() => isSubmitting = true);

    try {
      final orderId = await supabaseService.insertOrder(
        customerName: nameController.text.trim(),
        customerPhone: phoneController.text.trim(),
        customerAddress: addressController.text.trim(),
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

  void showCustomItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Custom Item Type"),
        content: TextField(
          controller: customItemController,
          decoration: const InputDecoration(hintText: "Eg. Curtain, Rug"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (customItemController.text.trim().isNotEmpty) {
                addClothingItem(customItemController.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    phoneController.addListener(() {
      if (phoneController.text.length == 10) {
        fetchAndPrefillCustomer(phoneController.text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('New Pickup', style: TextStyle(color: Colors.white)),
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
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
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
              const SizedBox(height: 20),
              const Text(
                'Select Items',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: itemTypes.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.75, // Reduce if content is tall
                ),
                itemBuilder: (context, index) {
                  final item = itemTypes[index];
                  final existing = clothes.firstWhere(
                        (c) => c['item_type'] == item['label'],
                    orElse: () => {},
                  );
                  final isSelected = existing.isNotEmpty;
                  final quantity = existing['quantity'] ?? 0;

                  return InkWell(
                    onTap: () {
                      if (item['label'] == 'Custom') {
                        showCustomItemDialog();
                      } else {
                        setState(() {
                          final existingItemIndex = clothes.indexWhere(
                                (c) => c['item_type'] == item['label'],
                          );

                          if (existingItemIndex != -1) {
                            clothes[existingItemIndex]['quantity']++;
                          } else {
                            clothes.add({'item_type': item['label'], 'quantity': 1});
                          }
                        });
                      }
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                item['iconPath'],
                                width: 30,
                                height: 30,
                                color: const Color(0xFF6A11CB),
                              ),
                              const SizedBox(height: 4),
                              Flexible(
                                child: Text(
                                  item['label'],
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (isSelected)
                                Flexible(
                                  child: FittedBox(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 18),
                                          onPressed: () {
                                            setState(() {
                                              final idx = clothes.indexWhere(
                                                    (c) => c['item_type'] == item['label'],
                                              );
                                              if (idx != -1) {
                                                if (clothes[idx]['quantity'] > 1) {
                                                  clothes[idx]['quantity']--;
                                                } else {
                                                  clothes.removeAt(idx);
                                                }
                                              }
                                            });
                                          },
                                        ),
                                        Text('$quantity'),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 18),
                                          onPressed: () {
                                            setState(() {
                                              final idx = clothes.indexWhere(
                                                    (c) => c['item_type'] == item['label'],
                                              );
                                              if (idx != -1) {
                                                clothes[idx]['quantity']++;
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              )
              ,
              const SizedBox(height: 20),
              const Text(
                "Selected Items",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...clothes.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(item['item_type'] ?? ''),
                    trailing: FittedBox(
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              setState(() {
                                if (item['quantity'] > 1) item['quantity']--;
                              });
                            },
                          ),
                          Text(item['quantity'].toString()),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              setState(() => item['quantity']++);
                            },
                          ),
                        ],
                      ),
                    ),
                    onLongPress: () => setState(() => clothes.removeAt(index)),
                  ),
                );
              }),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.done),
                  label: Text(
                    isSubmitting ? 'Submitting...' : 'Submit & Pickup',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
