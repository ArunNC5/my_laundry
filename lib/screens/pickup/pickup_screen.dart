import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  final FocusNode nameFocus = FocusNode();
  final FocusNode phoneFocus = FocusNode();
  final FocusNode addressFocus = FocusNode();

  List<Map<String, dynamic>> clothes = [];
  bool isSubmitting = false;

  List<Map<String, dynamic>> itemTypes = [];

  List<Map<String, dynamic>> get washingItems =>
      itemTypes.where((item) => item['category'] == 'Washing').toList();

  List<Map<String, dynamic>> get ironingItems =>
      itemTypes.where((item) => item['category'] == 'Ironing').toList();

  void addClothingItem(Map<String, dynamic> item) {
    setState(() {
      final index = clothes.indexWhere(
        (c) => c['name'] == item['name'] && c['category'] == item['category'],
      );

      if (index != -1) {
        clothes[index]['quantity']++;
      } else {
        clothes.add({
          'name': item['name'],
          'category': item['category'],
          'price': item['price'],
          'quantity': 1,
        });
      }
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
    final isValid = _formKey.currentState!.validate();

    if (!isValid) {
      // Manual checks for focus + snackbar
      if (nameController.text.trim().isEmpty) {
        FocusScope.of(context).requestFocus(nameFocus);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter customer name')),
        );
      } else if (phoneController.text.trim().isEmpty) {
        FocusScope.of(context).requestFocus(phoneFocus);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter phone number')),
        );
      } else if (addressController.text.trim().isEmpty) {
        FocusScope.of(context).requestFocus(addressFocus);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please enter address')));
      }
      return;
    }

    if (clothes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      double totalPrice = 0;
      for (var item in clothes) {
        final itemPrice = item['price'] ?? 0;
        totalPrice += itemPrice * item['quantity'];
      }

      final orderId = await supabaseService.insertOrder(
        customerName: nameController.text.trim(),
        customerPhone: "91${phoneController.text.trim()}",
        customerAddress: addressController.text.trim(),
        status: 'picked_up',
        pickupTime: DateTime.now(),
        deliveryDueTime: DateTime.now().add(const Duration(hours: 36)),
        totalPrice: totalPrice.toInt(),
      );

      for (var item in clothes) {
        await supabaseService.insertOrderItem(
          orderId: orderId,
          itemType: item['name'],
          quantity: item['quantity'],
          itemPrice: item['price'],
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
    final TextEditingController nameController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    String selectedCategory = 'Custom';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Custom Item"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Item Name",
                hintText: "e.g. Curtain, Rug",
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Price",
                hintText: "e.g. 50",
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: ['Custom', 'Washing', 'Ironing']
                  .map(
                    (cat) => DropdownMenuItem(
                      value: cat, // <-- DON'T lowercase here
                      child: Text(cat),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedCategory = value;
                  });
                }
              },
              decoration: const InputDecoration(labelText: "Category"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text.trim()) ?? 0;

              if (name.isNotEmpty) {
                addClothingItem({
                  'name': name,
                  'category': selectedCategory,
                  'price': price.toInt(),
                });
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
    loadServices();
  }

  Future<void> loadServices() async {
    final fetched = await supabaseService.fetchAllServices();
    setState(() {
      itemTypes = fetched;
    });
  }

  Widget buildItemGrid(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: Color(0xFF6A11CB)),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75, // Adjusted for more vertical room
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final existing = clothes.firstWhere(
          (c) => c['name'] == item['name'] && c['category'] == item['category'],
          orElse: () => {},
        );
        final isSelected = existing.isNotEmpty;
        final quantity = existing['quantity'] ?? 0;

        return InkWell(
          onTap: () {
            if (item['name'] == 'Custom') {
              showCustomItemDialog();
            } else {
              setState(() {
                final existingItemIndex = clothes.indexWhere(
                  (c) =>
                      c['name'] == item['name'] &&
                      c['category'] == item['category'],
                );

                if (existingItemIndex != -1) {
                  clothes[existingItemIndex]['quantity']++;
                } else {
                  clothes.add({
                    'name': item['name'],
                    'quantity': 1,
                    'category': item['category'],
                    'price': item['price'],
                  });
                }
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/${item['icon_name']}',
                  width: 50,
                  height: 50,
                  color: const Color(0xFF6A11CB),
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                      size: 40,
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  item['name'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                if (isSelected)
                  SizedBox(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 22,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              final idx = clothes.indexWhere(
                                (c) =>
                                    c['name'] == item['name'] &&
                                    c['category'] == item['category'],
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
                        Text(
                          '$quantity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 22),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              final idx = clothes.indexWhere(
                                (c) =>
                                    c['name'] == item['name'] &&
                                    c['category'] == item['category'],
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
                focusNode: nameFocus,
                decoration: inputDecoration('Customer Name'),
                validator: (v) => v!.isEmpty ? 'Enter name' : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                focusNode: phoneFocus,
                decoration: inputDecoration('Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  final phone = v?.trim() ?? '';
                  if (phone.isEmpty) return 'Enter phone number';
                  if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
                    return 'Enter a valid 10-digit number';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressController,
                focusNode: addressFocus,
                decoration: inputDecoration('Address'),
                validator: (v) => v!.isEmpty ? 'Enter address' : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 20),
              const Text(
                'Washing Services',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              buildItemGrid(washingItems),
              const SizedBox(height: 20),
              const Text(
                'Ironing Services',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              buildItemGrid(ironingItems),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 200, // Adjust as needed for layout
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text(
                        "Add Custom Item",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A11CB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: Colors.black45,
                      ),
                      onPressed: showCustomItemDialog,
                    ),
                  ),
                ),
              ),
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
                    title: Text(item['name'] ?? ''),
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
