import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final SupabaseService supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> services = [];
  String? editingId;

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
    _scrollController.dispose();
    nameController.dispose();
    priceController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  Future<void> fetchServices() async {
    final data = await supabaseService.fetchAllServices();
    setState(() => services = data);
  }

  void clearForm() {
    editingId = null;
    nameController.clear();
    priceController.clear();
    categoryController.clear();
    setState(() {});
  }

  void populateForm(Map<String, dynamic> service) {
    editingId = service['id'];
    nameController.text = service['name'];
    priceController.text = service['price'].toString();
    categoryController.text = service['category'];
    setState(() {});

    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    });
  }

  Future<void> handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      final name = nameController.text.trim();
      final price = int.parse(priceController.text.trim());
      final category = categoryController.text.trim();

      if (editingId != null) {
        await supabaseService.updateService(
          id: editingId!,
          name: name,
          price: price,
          category: category,
        );
      } else {
        await supabaseService.insertService(
          name: name,
          price: price,
          category: category,
        );
      }

      clearForm();
      fetchServices();
    }
  }

  Widget _serviceTile(Map<String, dynamic> service) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(service['name']),
        subtitle: Text("₹${service['price']}"),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => populateForm(service),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 Grouping by category happens here
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final s in services) {
      final category = s['category'] ?? 'Others';
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
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔹 Form section (unchanged)
            Form(
              key: _formKey,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: "Service Name"),
                        validator: (v) => v!.isEmpty ? "Enter name" : null,
                      ),
                      TextFormField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Price"),
                        validator: (v) => v!.isEmpty ? "Enter price" : null,
                      ),
                      TextFormField(
                        controller: categoryController,
                        decoration: const InputDecoration(labelText: "Category"),
                        validator: (v) => v!.isEmpty ? "Enter category" : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: handleSubmit,
                              child: Text(editingId == null ? "Add Service" : "Update Service"),
                            ),
                          ),
                          if (editingId != null)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: clearForm,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),

            // 🔥 Category-wise grouped list UI
            ...grouped.entries.map((entry) {
              final category = entry.key;
              final items = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2575FC),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...items.map((service) => _serviceTile(service)),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
