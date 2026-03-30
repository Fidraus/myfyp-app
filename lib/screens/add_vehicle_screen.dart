import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../services/session_service.dart';
import '../config/api_config.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _mileageController = TextEditingController();
  String _selectedType = 'Car';
  bool _isLoading = false;

  Future<void> _submitVehicle() async {
    if (_plateController.text.isEmpty || _brandController.text.isEmpty ||
        _modelController.text.isEmpty) {
      _showSnack('Please fill all required fields');
      return;
    }

    setState(() => _isLoading = true);
    final userId = await SessionService.getUserId() ?? 1;
    final url = Uri.parse('${ApiConfig.baseUrl}/vehicles');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'plate_number': _plateController.text.trim().toUpperCase(),
          'brand': _brandController.text.trim(),
          'model': _modelController.text.trim(),
          'type': _selectedType,
          'mileage': double.tryParse(_mileageController.text) ?? 0,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        if (mounted) {
          _showSnack('Vehicle added successfully!');
          Navigator.pop(context);
        }
      } else {
        _showSnack('Failed to add vehicle. Server responded with ${response.statusCode}');
      }
    } on TimeoutException {
      _showSnack('Request timed out. Please check your connection.');
    } catch (e) {
      _showSnack('Connection error. Is the server running?');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Add New Vehicle', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle type selector
            _label('Vehicle Type'),
            Row(
              children: ['Car', 'Motorcycle'].map((type) {
                final selected = _selectedType == type;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF1565C0) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? const Color(0xFF1565C0) : Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              type == 'Car' ? Icons.directions_car : Icons.two_wheeler,
                              color: selected ? Colors.white : Colors.grey.shade600,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(type, style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w500,
                              color: selected ? Colors.white : Colors.grey.shade700,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            _label('Plate Number'),
            _field(
              controller: _plateController,
              hint: 'e.g., VAA 1234',
              icon: Icons.pin_outlined,
              caps: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),

            _label('Brand'),
            _field(controller: _brandController, hint: 'e.g., Perodua, Honda, Toyota', icon: Icons.branding_watermark_outlined),
            const SizedBox(height: 16),

            _label('Model'),
            _field(controller: _modelController, hint: 'e.g., Myvi, RS150R, Vios', icon: Icons.commute_outlined),
            const SizedBox(height: 16),

            _label('Current Mileage (km)'),
            _field(
              controller: _mileageController,
              hint: 'e.g., 15000',
              icon: Icons.speed_outlined,
              keyboard: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Text('This will be used to track your vehicle\'s mileage accurately.',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitVehicle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text('Save Vehicle', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
    TextCapitalization caps = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      textCapitalization: caps,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
      ),
    );
  }
}