import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'vehicle_detail_screen.dart';
import '../config/api_config.dart';

class GarageView extends StatelessWidget {
  final List<dynamic> vehicles;
  final bool isLoading;
  final VoidCallback onRefresh;

  const GarageView({super.key, required this.vehicles, required this.isLoading, required this.onRefresh});

  // ── Delete vehicle via API ─────────────────────────────────────────────────
  Future<void> _deleteVehicle(BuildContext context, Map<String, dynamic> v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Vehicle', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete ${v['plate_number']} (${v['brand']} ${v['model']})?\n\nThis will also delete all service records.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade600))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final res = await http.delete(Uri.parse('${ApiConfig.baseUrl}/vehicles/${v['id']}'));
      if (res.statusCode == 200 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle deleted successfully.'), backgroundColor: Colors.red));
        onRefresh();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete vehicle.')));
      }
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error.')));
    }
  }

  // ── Edit vehicle inline bottom sheet ──────────────────────────────────────
  void _showEditSheet(BuildContext context, Map<String, dynamic> v) {
    final plateCtrl   = TextEditingController(text: v['plate_number'] ?? '');
    final brandCtrl   = TextEditingController(text: v['brand'] ?? '');
    final modelCtrl   = TextEditingController(text: v['model'] ?? '');
    final mileageCtrl = TextEditingController(text: (v['mileage'] ?? '0').toString());
    String selectedType = v['type'] ?? 'Car';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 16),
              Text('Edit Vehicle', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Type selector
              Row(children: ['Car', 'Motorcycle'].map((t) {
                final sel = selectedType == t;
                return Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setSheet(() => selectedType = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF1565C0) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? const Color(0xFF1565C0) : Colors.grey.shade200),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(t == 'Car' ? Icons.directions_car : Icons.two_wheeler,
                          color: sel ? Colors.white : Colors.grey.shade600, size: 18),
                        const SizedBox(width: 6),
                        Text(t, style: GoogleFonts.poppins(fontSize: 13, color: sel ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                ));
              }).toList()),
              const SizedBox(height: 14),

              _sheetField(ctrl: plateCtrl, hint: 'Plate Number', icon: Icons.pin_outlined, caps: TextCapitalization.characters),
              const SizedBox(height: 10),
              _sheetField(ctrl: brandCtrl, hint: 'Brand (e.g. Honda)', icon: Icons.branding_watermark_outlined),
              const SizedBox(height: 10),
              _sheetField(ctrl: modelCtrl, hint: 'Model (e.g. Myvi)', icon: Icons.commute_outlined),
              const SizedBox(height: 10),
              _sheetField(ctrl: mileageCtrl, hint: 'Current Mileage (km)', icon: Icons.speed_outlined, keyboard: TextInputType.number),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    setSheet(() => saving = true);
                    try {
                      final res = await http.patch(
                        Uri.parse('${ApiConfig.baseUrl}/vehicles/${v['id']}'),
                        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
                        body: jsonEncode({
                          'plate_number': plateCtrl.text.trim().toUpperCase(),
                          'brand':         brandCtrl.text.trim(),
                          'model':         modelCtrl.text.trim(),
                          'type':          selectedType,
                          'mileage':       double.tryParse(mileageCtrl.text) ?? 0,
                        }),
                      );
                      if (res.statusCode == 200 && ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehicle updated!')));
                        onRefresh();
                      }
                    } catch (_) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Connection error.')));
                    }
                    setSheet(() => saving = false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Save Changes', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(children: [
                Text('My Garage', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              ]),
            ),
            Container(height: 1, color: Colors.grey.shade200),

            if (isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF1565C0))))
            else if (vehicles.isEmpty)
              Expanded(
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.garage_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No vehicles in garage', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text('Add a vehicle from the Home screen', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400)),
                ])),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: vehicles.length,
                  separatorBuilder: (context, idx) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final v = vehicles[index] as Map<String, dynamic>;
                    final isMoto = v['type'] == 'Motorcycle';
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicle: v)),
                        ).then((_) => onRefresh()),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(children: [
                            // Icon
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(isMoto ? Icons.two_wheeler : Icons.directions_car,
                                color: const Color(0xFF1565C0), size: 28),
                            ),
                            const SizedBox(width: 14),
                            // Info
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(v['plate_number'] ?? '-',
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 2),
                              Text('${v['brand']} ${v['model']}',
                                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.speed, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('${v['mileage'] ?? 0} km',
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isMoto ? Colors.orange.shade50 : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(isMoto ? '🏍 Motorcycle' : '🚗 Car',
                                    style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600,
                                      color: isMoto ? Colors.orange.shade700 : Colors.blue.shade700)),
                                ),
                              ]),
                            ])),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────
Widget _sheetField({
  required TextEditingController ctrl,
  required String hint,
  required IconData icon,
  TextInputType? keyboard,
  TextCapitalization caps = TextCapitalization.none,
}) {
  return TextField(
    controller: ctrl,
    keyboardType: keyboard,
    textCapitalization: caps,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
      filled: true, fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
    ),
  );
}