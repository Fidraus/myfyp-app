import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../config/api_config.dart';

// ── Per-service recommended thresholds ────────────────────────────────────────
class ServiceThreshold {
  final double? mileageKm;
  final int? months;
  const ServiceThreshold({this.mileageKm, this.months});
}

const Map<String, ServiceThreshold> kServiceThresholds = {
  'Oil Change':                  ServiceThreshold(mileageKm: 5000,  months: 3),
  'Tyre Replacement':            ServiceThreshold(mileageKm: 40000, months: 24),
  'Brake Service':               ServiceThreshold(mileageKm: 20000, months: 12),
  'Engine Tune-Up':              ServiceThreshold(mileageKm: 10000, months: 6),
  'Air Filter':                  ServiceThreshold(mileageKm: 15000, months: 12),
  'Battery Replacement':         ServiceThreshold(mileageKm: 60000, months: 24),
  'Transmission Service':        ServiceThreshold(mileageKm: 50000, months: 24),
  'Coolant Flush':               ServiceThreshold(mileageKm: 40000, months: 24),
  'AC Service':                  ServiceThreshold(mileageKm: null,  months: 12),
  'Full Inspection':             ServiceThreshold(mileageKm: 10000, months: 6),
  'Engine Oil':                  ServiceThreshold(mileageKm: 3000,  months: 3),
  'Chain Lube':                  ServiceThreshold(mileageKm: 500,   months: 1),
  'Chain Change':                ServiceThreshold(mileageKm: 15000, months: 12),
  'Brake Pad':                   ServiceThreshold(mileageKm: 20000, months: 12),
  'Spark Plug':                  ServiceThreshold(mileageKm: 20000, months: 24),
  'Drive Belt':                  ServiceThreshold(mileageKm: 25000, months: 24),
  'Carburetor / Throttle Body':  ServiceThreshold(mileageKm: 15000, months: 12),
  'Other':                       ServiceThreshold(mileageKm: null,  months: null),
};

const List<String> kCarServices = [
  'Oil Change', 'Tyre Replacement', 'Brake Service', 'Engine Tune-Up',
  'Air Filter', 'Battery Replacement', 'Transmission Service', 'Coolant Flush',
  'AC Service', 'Full Inspection', 'Other',
];

const List<String> kMotorcycleServices = [
  'Engine Oil', 'Chain Lube', 'Chain Change', 'Tyre Replacement', 'Brake Pad',
  'Air Filter', 'Spark Plug', 'Drive Belt', 'Carburetor / Throttle Body',
  'Battery Replacement', 'Full Inspection', 'Other',
];

class AddServiceRecordScreen extends StatefulWidget {
  final int vehicleId;
  final String vehiclePlate;
  final String vehicleType;
  /// Pre-seeded mileage from the calling screen (avoids extra API call in simple cases)
  final double? initialMileage;

  const AddServiceRecordScreen({
    super.key,
    required this.vehicleId,
    required this.vehiclePlate,
    this.vehicleType = 'Car',
    this.initialMileage,
  });

  @override
  State<AddServiceRecordScreen> createState() => _AddServiceRecordScreenState();
}

class _AddServiceRecordScreenState extends State<AddServiceRecordScreen> {
  final _mileageController    = TextEditingController();
  final _costController       = TextEditingController();
  final _notesController      = TextEditingController();
  final _customTypeController = TextEditingController();

  late List<String> _serviceTypes;
  late String _selectedType;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _mileageFetching = false;

  bool get _isMotorcycle => widget.vehicleType == 'Motorcycle';
  bool get _isOther => _selectedType == 'Other';
  ServiceThreshold get _currentThreshold =>
      kServiceThresholds[_selectedType] ?? const ServiceThreshold();

  @override
  void initState() {
    super.initState();
    _serviceTypes = _isMotorcycle ? kMotorcycleServices : kCarServices;
    _selectedType = _serviceTypes.first;
    // Pre-fill mileage
    if (widget.initialMileage != null) {
      _mileageController.text = widget.initialMileage!.toStringAsFixed(0);
    } else {
      _fetchMileage();
    }
  }

  @override
  void dispose() {
    _mileageController.dispose();
    _costController.dispose();
    _notesController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  Future<void> _fetchMileage() async {
    setState(() => _mileageFetching = true);
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/vehicles/${widget.vehicleId}'));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final mileage = double.tryParse(data['mileage']?.toString() ?? '0') ?? 0;
        _mileageController.text = mileage.toStringAsFixed(0);
      }
    } catch (_) {}
    if (mounted) setState(() => _mileageFetching = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1565C0)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (_costController.text.isEmpty) {
      _showSnack('Please fill in the cost');
      return;
    }
    if (_isOther && _customTypeController.text.trim().isEmpty) {
      _showSnack('Please describe the service type');
      return;
    }

    setState(() => _isLoading = true);
    final effectiveType = _isOther ? _customTypeController.text.trim() : _selectedType;
    final mileage = double.tryParse(_mileageController.text) ?? 0;

    final url = Uri.parse('${ApiConfig.baseUrl}/vehicles/${widget.vehicleId}/services');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'service_type':       effectiveType,
          'service_date':       _selectedDate.toIso8601String().substring(0, 10),
          'mileage_at_service': mileage,
          'cost':               double.tryParse(_costController.text) ?? 0,
          'notes':              _notesController.text.trim(),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          _showSnack('Service record saved!');
          Navigator.pop(context, true);
        }
      } else {
        _showSnack('Failed to save. Please try again.');
      }
    } catch (e) {
      _showSnack('Connection error.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final th = _currentThreshold;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Service Record', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
            Row(children: [
              Text(widget.vehiclePlate, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _isMotorcycle ? Colors.orange.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _isMotorcycle ? '🏍 Motorcycle' : '🚗 Car',
                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600,
                    color: _isMotorcycle ? Colors.orange.shade800 : Colors.blue.shade800),
                ),
              ),
            ]),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Service Type ────────────────────────────────────────────────
            _label('Service Type'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedType,
                  isExpanded: true,
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                  items: _serviceTypes.map((t) => DropdownMenuItem(
                    value: t,
                    child: t == 'Other' ? Row(children: [
                      const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 8), Text(t),
                    ]) : Text(t),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedType = v!),
                ),
              ),
            ),

            // Custom type input
            if (_isOther) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customTypeController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Describe the service (e.g., Wiper Blade)',
                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
                ),
              ),
              const SizedBox(height: 6),
              // "Other" info banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade200)),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(child: Text('"Other" is recorded only — no future reminder will be created.',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.amber.shade900))),
                ]),
              ),
            ],

            // Threshold chip for known types
            if (!_isOther && (th.mileageKm != null || th.months != null)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFF1565C0).withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF1565C0)),
                  const SizedBox(width: 6),
                  Text(
                    'Reminder auto-set: '
                    '${th.mileageKm != null ? "+${th.mileageKm!.toInt()} km" : ""}'
                    '${th.mileageKm != null && th.months != null ? " or " : ""}'
                    '${th.months != null ? "${th.months} month${th.months! > 1 ? "s" : ""}" : ""}',
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF1565C0)),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 16),

            // ── Date ────────────────────────────────────────────────────────
            _label('Service Date'),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey.shade500),
                  const SizedBox(width: 12),
                  Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // ── Mileage (auto-filled) + Cost ────────────────────────────────
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Mileage (km)', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  if (_mileageFetching)
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey.shade400))
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                      child: Text('auto', style: GoogleFonts.poppins(fontSize: 9, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                    ),
                ]),
                const SizedBox(height: 8),
                _field(controller: _mileageController, hint: 'current km', icon: Icons.speed_outlined, keyboard: TextInputType.number),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Cost (RM)'),
                _field(controller: _costController, hint: 'e.g., 85.00', icon: Icons.payments_outlined,
                  keyboard: const TextInputType.numberWithOptions(decimal: true)),
              ])),
            ]),
            const SizedBox(height: 16),

            // ── Notes ───────────────────────────────────────────────────────
            _label('Notes (optional)'),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g., Changed to fully synthetic oil...',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text('Save Record', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
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

  Widget _field({required TextEditingController controller, required String hint,
      required IconData icon, TextInputType? keyboard}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
      ),
    );
  }
}
