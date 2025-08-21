import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for input formatters
import 'package:http/http.dart' as http;

import '../../services/supabase_service.dart';
import '../home/home_screen.dart';
import '../home/order_detail.dart';

class PickupScreen extends StatefulWidget {
  final Map<String, dynamic>? order; // Make order nullable for new pickups

  const PickupScreen({super.key, this.order}); // Accept optional order

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  final SupabaseService supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  // Removed customItemController as it was unused and replaced by dialog logic

  final FocusNode nameFocus = FocusNode();
  final FocusNode phoneFocus = FocusNode();
  final FocusNode addressFocus = FocusNode();

  List<Map<String, dynamic>> clothes = [];
  bool isSubmitting = false;

  List<Map<String, dynamic>> itemTypes = [];

  List<Map<String, dynamic>> get ironingItems =>
      itemTypes.where((item) => item['category'] == 'Ironing').toList();

  List<Map<String, dynamic>> get washingItems =>
      itemTypes.where((item) => item['category'] == 'Washing').toList();

  @override
  void initState() {
    super.initState();
    _initializeFields(); // NEW: Method to handle prefilling existing orders
    phoneController.addListener(_onPhoneChanged);
    loadServices();
  }

  // NEW: Method to pre-fill fields if an existing order is passed
  void _initializeFields() async {
    if (widget.order != null) {
      // Pre-fill fields for existing order
      nameController.text = widget.order!['customer_name'] ?? '';
      // Assuming phone number comes as '91XXXXXXXXXX', extract last 10 digits
      String? fullPhoneNumber = widget.order!['customer_phone'];
      if (fullPhoneNumber != null &&
          fullPhoneNumber.startsWith('91') &&
          fullPhoneNumber.length == 12) {
        phoneController.text = fullPhoneNumber.substring(2);
      } else {
        phoneController.text =
            fullPhoneNumber ?? ''; // Fallback for other formats/null
      }
      addressController.text = widget.order!['customer_address'] ?? '';

      // Load existing order items into the 'clothes' list
      await _loadOrderItemsForExistingOrder(widget.order!['id'].toString());
    }
  }

  // NEW: Method to fetch and load items for an existing order
  Future<void> _loadOrderItemsForExistingOrder(String orderId) async {
    try {
      final items = await supabaseService.fetchOrderItems(orderId);
      setState(() {
        clothes = items
            .map(
              (item) => {
                'name': item['item_type'],
                'category': item['category'] ?? 'Custom',
                // Ensure category is available
                'price':
                    int.tryParse(item['item_price']?.toString() ?? '0') ?? 0,
                // Ensure price is int
                'quantity':
                    int.tryParse(item['quantity']?.toString() ?? '0') ?? 0,
                // Ensure quantity is int
              },
            )
            .toList();
      });
    } catch (e) {
      print('Error loading existing order items: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading existing items: $e')),
      );
    }
  }

  // Listener for phone number changes to trigger customer prefill
  void _onPhoneChanged() {
    // Only trigger prefill if phone number has exactly 10 digits
    // And if the name/address fields are currently empty (to avoid overwriting user input)
    if (phoneController.text.length == 10 &&
        nameController.text.isEmpty &&
        addressController.text.isEmpty) {
      fetchAndPrefillCustomer(phoneController.text);
    }
  }

  void addClothingItem(Map<String, dynamic> item) {
    setState(() {
      final index = clothes.indexWhere(
        (c) => c['name'] == item['name'] && c['category'] == item['category'],
      );

      // Ensure item['price'] is an int before adding
      final int itemPrice = int.tryParse(item['price']?.toString() ?? '0') ?? 0;

      if (index != -1) {
        clothes[index]['quantity']++;
      } else {
        clothes.add({
          'name': item['name'],
          'category': item['category'],
          'price': itemPrice,
          'quantity': 1,
        });
      }
    });
  }

  Future<void> fetchAndPrefillCustomer(String phone) async {
    // This function is only called when phone.length == 10 by _onPhoneChanged
    final existingCustomer = await supabaseService.fetchLatestCustomerByPhone(
      "91$phone", // Pass with country code for Supabase query
    );
    print('Fetched customer: $existingCustomer');

    if (existingCustomer != null) {
      // Only prefill if the fields are currently empty to avoid overwriting user input
      if (nameController.text.isEmpty) {
        nameController.text = existingCustomer['customer_name'] ?? '';
      }
      if (addressController.text.isEmpty) {
        addressController.text = existingCustomer['customer_address'] ?? '';
      }
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
      // Calculate total price
      double calculatedTotalPrice = 0;
      for (var item in clothes) {
        final itemPrice = (item['price'] is num)
            ? (item['price'] as num).toDouble()
            : (double.tryParse(item['price']?.toString() ?? '0') ?? 0.0);
        final itemQuantity = (item['quantity'] is num)
            ? (item['quantity'] as num).toInt()
            : (int.tryParse(item['quantity']?.toString() ?? '0') ?? 0);
        calculatedTotalPrice += itemPrice * itemQuantity;
      }

      String orderId;

      if (widget.order != null) {
        // Update existing order
        orderId = widget.order!['id'];

        await supabaseService.updateOrder(
          orderId: orderId,
          customerName: nameController.text.trim(),
          customerPhone: "91${phoneController.text.trim()}",
          customerAddress: addressController.text.trim(),
          status: 'picked_up',
          totalPrice: calculatedTotalPrice.toInt(),
          pickupTime: DateTime.now(),
          deliveryDueTime: DateTime.now().add(const Duration(hours: 36)),
        );

        await supabaseService.deleteOrderItems(orderId);

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
      } else {
        // Insert new order
        orderId = await supabaseService.insertOrder(
          customerName: nameController.text.trim(),
          customerPhone: "91${phoneController.text.trim()}",
          customerAddress: addressController.text.trim(),
          status: 'picked_up',
          pickupTime: DateTime.now(),
          deliveryDueTime: DateTime.now().add(const Duration(hours: 36)),
          totalPrice: calculatedTotalPrice.toInt(),
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
      }

      // ✅ WhatsApp message sending (shared for both flows)
      StringBuffer itemListBuffer = StringBuffer();
      for (var item in clothes) {
        itemListBuffer.writeln("• ${item['name']} × ${item['quantity']}");
      }

      String message =
          """
🧺 *Laundry Pickup Confirmed!*

Hello ${nameController.text.trim()},
We have picked up your laundry items:

${itemListBuffer.toString().trim()}

📅 Estimated delivery: within 36 hours.

Thank you for choosing our service!
""";

      await sendTextMessageToWhatsApp(
        "91${phoneController.text.trim()}",
        message,
      );

      // Success message (depends on flow)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.order != null
                ? 'Order pickup confirmed and updated!'
                : 'New pickup successfully created!',
          ),
        ),
      );

      // Navigate to Home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => HomeScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  Future<void> sendTextMessageToWhatsApp(
    String phoneNumber,
    String message,
  ) async {
    final uri = Uri.parse(
      'https://graph.facebook.com/v22.0/$phoneNumberId/messages',
    );

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "messaging_product": "whatsapp",
        "to": phoneNumber,
        "type": "text",
        "text": {"body": message},
      }),
    );

    if (response.statusCode == 200) {
      print('✅ Text message sent successfully');
    } else {
      print('❌ Text send failed: ${response.body}');
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
    String selectedCategory = 'Custom'; // Default for custom items

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
              items:
                  [
                        'Custom',
                        'Washing',
                        'Ironing',
                      ] // Include 'Custom' as an option
                      .map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  selectedCategory = value; // Update the local variable
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
                  'price': price.toInt(), // Ensure price is int
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
  void dispose() {
    nameController.dispose();
    phoneController.removeListener(_onPhoneChanged); // Remove listener
    phoneController.dispose();
    addressController.dispose();
    nameFocus.dispose();
    phoneFocus.dispose();
    addressFocus.dispose();
    super.dispose();
  }

  Future<void> loadServices() async {
    try {
      print('DEBUG: Attempting to load services from Supabase...');
      // This is the critical call. We need to see what it returns.
      final fetched = await supabaseService.fetchAllServices();
      print('DEBUG: Raw data fetched from Supabase for services: $fetched');

      if (fetched.isEmpty) {
        print(
          'DEBUG: No services found or fetch returned empty/null data. Check Supabase table and RLS.',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No laundry services found. Please configure in Supabase.',
              ),
            ),
          );
        }
        setState(() {
          itemTypes = []; // Ensure itemTypes is explicitly empty
        });
        return; // Exit if no data
      }

      setState(() {
        itemTypes = fetched.map<Map<String, dynamic>>((item) {
          // Add null checks and default values for robustness
          return {
            'id': item['id'],
            'name': item['name'] as String? ?? 'Unknown Item',
            // Provide default if null
            'category': item['category'] as String? ?? 'Custom',
            // Provide default if null
            'price': int.tryParse(item['price']?.toString() ?? '0') ?? 0,
            'icon_name': item['icon_name'] != null
                ? '${item['icon_name']}.png'
                : 'default_icon.png',
            // Provide default
          };
        }).toList();
        print('DEBUG: Processed itemTypes after mapping: $itemTypes');
      });
      print(
        'DEBUG: Services loaded successfully. Item count: ${itemTypes.length}',
      );
    } catch (e) {
      // This block will catch any errors thrown during the Supabase call or data processing
      print('ERROR: Failed to load services: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading services: $e')));
      }
      setState(() {
        itemTypes =
            []; // Ensure state is reset on error to prevent infinite loader
      });
    }
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
        childAspectRatio: 0.7,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        // Ensure item has 'name', 'category', 'price' keys from your Supabase fetch
        final String itemName = item['name'] ?? 'Unknown Item';
        final String itemCategory = item['category'] ?? 'Uncategorized';
        // Ensure itemPrice is int
        final int itemPrice =
            int.tryParse(item['price']?.toString() ?? '0') ?? 0;

        final existing = clothes.firstWhere(
          (c) => c['name'] == itemName && c['category'] == itemCategory,
          orElse: () => {},
        );
        final isSelected = existing.isNotEmpty;
        final quantity = existing['quantity'] ?? 0;

        return InkWell(
          onTap: () {
            // This grid is for predefined items, custom items have a dedicated button
            setState(() {
              final existingItemIndex = clothes.indexWhere(
                (c) => c['name'] == itemName && c['category'] == itemCategory,
              );

              if (existingItemIndex != -1) {
                clothes[existingItemIndex]['quantity']++;
              } else {
                clothes.add({
                  'name': itemName,
                  'quantity': 1,
                  'category': itemCategory,
                  'price': itemPrice, // Use the parsed int price
                });
              }
            });
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
                  // Make sure 'icon_name' exists for all services
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
                Flexible(
                  child: Text(
                    itemName,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    maxLines: null, // unlimited lines
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
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
                                    c['name'] == itemName &&
                                    c['category'] == itemCategory,
                              );
                              if (idx != -1) {
                                if (clothes[idx]['quantity'] > 1) {
                                  clothes[idx]['quantity']--;
                                } else {
                                  clothes.removeAt(
                                    idx,
                                  ); // Remove if quantity is 1
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
                                    c['name'] == itemName &&
                                    c['category'] == itemCategory,
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
        title: Text(
          widget.order != null ? 'Edit Pickup Order' : 'New Pickup Order',
          // Dynamic title
          style: const TextStyle(color: Colors.white),
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
                maxLength: 10,
                // Max length for user input
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
                  final phone = v?.trim() ?? '';
                  if (phone.isEmpty) return 'Enter phone number';
                  if (phone.length != 10) {
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
                'Ironing Services',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              buildItemGrid(ironingItems),
              const SizedBox(height: 10),
              const Text(
                'Washing Services',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              buildItemGrid(washingItems),
              const SizedBox(height: 20),

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
              // Only show selected items section if there are items
              if (clothes.isNotEmpty) ...[
                const Text(
                  "Selected Items",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...clothes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(item['name'] ?? ''),
                      subtitle: Text(
                        'Category: ${item['category'] ?? 'N/A'} - Price: ₹${item['price'] ?? 0}',
                      ),
                      trailing: FittedBox(
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                setState(() {
                                  if (item['quantity'] > 1) {
                                    item['quantity']--;
                                  } else {
                                    clothes.removeAt(
                                      index,
                                    ); // Remove if quantity is 1
                                  }
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
                      onLongPress: () {
                        // Option to remove item completely with a long press
                        setState(() => clothes.removeAt(index));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${item['name']} removed.')),
                        );
                      },
                    ),
                  );
                }),
                const SizedBox(height: 30),
              ],
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
                    isSubmitting
                        ? 'Submitting...'
                        : widget.order != null
                        ? 'Confirm Pickup & Update'
                        : 'Submit & Pickup', // Dynamic button text
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: const Color(0xFF6A11CB),
                    foregroundColor: Colors.white,
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
