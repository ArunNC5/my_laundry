import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final SupabaseService supabaseService = SupabaseService();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> services = [];
  String? editingId;
  bool isLoading = true;

  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchServices();
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    categoryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchServices() async {
    setState(() => isLoading = true);

    final data = await supabaseService.fetchAllServices();

    setState(() {
      services = data;
      isLoading = false;
    });
  }


  void _openServiceDialog({Map<String, dynamic>? service}) {
    if (service != null) {
      // Editing existing
      editingId = service['id'];
      nameController.text = service['name'];
      priceController.text = service['price'].toString();
      categoryController.text = service['category'];
    } else {
      // Adding new
      editingId = null;
      nameController.clear();
      priceController.clear();
      categoryController.clear();
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                editingId == null ? "Add Service" : "Update Service",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),

              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Service Name",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Price",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              TextField(
                controller: categoryController,
                decoration: InputDecoration(
                  labelText: "Category",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.black87),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2575FC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      await _saveService();
                      Navigator.pop(context);
                    },
                    child: Text(
                      editingId == null ? "Add" : "Update",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveService() async {
    final name = nameController.text.trim();
    final price = int.tryParse(priceController.text.trim()) ?? 0;
    final category = categoryController.text.trim();

    if (editingId == null) {
      await supabaseService.insertService(
        name: name,
        price: price,
        category: category,
      );
    } else {
      await supabaseService.updateService(
        id: editingId!,
        name: name,
        price: price,
        category: category,
      );
    }

    await fetchServices();
  }

  Widget _serviceTile(Map<String, dynamic> service) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          service['name'],
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          "₹${service['price']}",
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          onPressed: () => _openServiceDialog(service: service),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final s in services) {
      final category = (s['category'] ?? 'Others').toString();
      grouped.putIfAbsent(category, () => []);
      grouped[category]!.add(s);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Services',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        centerTitle: true,
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
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2575FC),
                ),
              )
                  : services.isEmpty
                  ? const Center(
                child: Text(
                  "No services added yet",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
                  : ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 90),
                children: grouped.entries.map((entry) {
                  final category = entry.key;
                  final items = entry.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2575FC),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...items.map(_serviceTile),
                    ],
                  );
                }).toList(),
              ),
            )
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        foregroundColor: const Color(0xFFFFFFFF),
        backgroundColor: const Color(0xFF2575FC),
        child: const Icon(Icons.add, size: 28),
        onPressed: () => _openServiceDialog(),
      ),
    );
  }
}
