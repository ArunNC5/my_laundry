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
  final iconUrlController = TextEditingController();

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
    iconUrlController.dispose();
    super.dispose();
  }

  Future<void> fetchServices() async {
    final data = await supabaseService.fetchAllServices();
    setState(() => services = data);
  }

  void clearForm() {
    nameController.clear();
    priceController.clear();
    categoryController.clear();
    iconUrlController.clear();
    editingId = null;
    setState(() {});
  }

  void populateForm(Map<String, dynamic> service) {
    editingId = service['id'];
    nameController.text = service['name'] ?? '';
    priceController.text = service['price'].toString();
    categoryController.text = service['category'] ?? '';
    iconUrlController.text = service['icon_url'] ?? '';
    setState(() {});

    // Scroll to top where the form is located
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      final name = nameController.text.trim();
      final price = int.tryParse(priceController.text.trim()) ?? 0;
      final category = categoryController.text.trim();
      final iconUrl = iconUrlController.text.trim().isEmpty
          ? null
          : iconUrlController.text.trim();

      if (editingId != null) {
        await supabaseService.updateService(
          id: editingId!,
          name: name,
          price: price,
          category: category,
          iconUrl: iconUrl,
        );
      } else {
        await supabaseService.insertService(
          name: name,
          price: price,
          category: category,
          iconUrl: iconUrl,
        );
      }

      clearForm();
      fetchServices();
    }
  }

  Future<void> handleDelete(String id) async {
    await supabaseService.deleteService(id);
    fetchServices();
  }

  @override
  Widget build(BuildContext context) {
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
            Form(
              key: _formKey,
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Service Name'),
                        validator: (value) => value!.isEmpty ? 'Enter name' : null,
                      ),
                      TextFormField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Price'),
                        validator: (value) =>
                        value!.isEmpty ? 'Enter price' : null,
                      ),
                      TextFormField(
                        controller: categoryController,
                        decoration: const InputDecoration(labelText: 'Category'),
                        validator: (value) =>
                        value!.isEmpty ? 'Enter category' : null,
                      ),
                      // TextFormField(
                      //   controller: iconUrlController,
                      //   decoration:
                      //   const InputDecoration(labelText: 'Icon URL (optional)'),
                      // ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(editingId != null ? Icons.save : Icons.add),
                              onPressed: handleSubmit,
                              label: Text(editingId != null ? 'Update Service' : 'Add Service'),
                            ),
                          ),
                          if (editingId != null) ...[
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: clearForm,
                              tooltip: 'Cancel editing',
                            )
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    // leading: service['icon_url'] != null
                    //     ? Image.network(service['icon_url'], width: 40, height: 40)
                    //     : const Icon(Icons.local_laundry_service),
                    title: Text(service['name']),
                    subtitle: Text('₹${service['price']} • ${service['category']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => populateForm(service),
                        ),
                        // IconButton(
                        //   icon: const Icon(Icons.delete, color: Colors.red),
                        //   onPressed: () => handleDelete(service['id']),
                        // ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
