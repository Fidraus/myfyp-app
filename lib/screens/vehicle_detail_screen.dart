import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'add_service_record_screen.dart';
import '../config/api_config.dart';

class VehicleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  late Map<String, dynamic> _vehicle;
  List<dynamic> _serviceRecords = [];
  bool _loadingRecords = true;
  double _totalCost = 0;
  late double _currentMileage;

  @override
  void initState() {
    super.initState();
    _vehicle = Map<String, dynamic>.from(widget.vehicle);
    _currentMileage = double.tryParse(_vehicle['mileage']?.toString() ?? '0') ?? 0;
    _fetchServiceRecords();
  }

  Future<void> _fetchServiceRecords() async {
    final vId = _vehicle['id'];
    final url = Uri.parse('${ApiConfig.baseUrl}/vehicles/$vId/services');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200 && mounted) {
        final records = jsonDecode(response.body) as List;
        double total = 0;
        final completedRecords = [];
        for (final r in records) {
          if (r['status'] == 'completed' || r['status'] == null) {
            total += double.tryParse(r['cost']?.toString() ?? '0') ?? 0;
            completedRecords.add(r);
          }
        }
        setState(() {
          _serviceRecords = completedRecords;
          _totalCost = total;
          _loadingRecords = false;
        });
      } else {
        if (mounted) setState(() => _loadingRecords = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRecords = false);
    }
  }

  // ── Vehicle Actions ────────────────────────────────────────────────────────
  Future<void> _deleteVehicle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Vehicle', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Delete ${_vehicle['plate_number']}?\nThis will remove all associated service records.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade600))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, elevation: 0),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      final res = await http.delete(Uri.parse('${ApiConfig.baseUrl}/vehicles/${_vehicle['id']}'));
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehicle deleted'), backgroundColor: Colors.red));
        Navigator.pop(context);
      }
    } catch (_) {}
  }

  void _showEditVehicleSheet() {
    final plateCtrl = TextEditingController(text: _vehicle['plate_number'] ?? '');
    final brandCtrl = TextEditingController(text: _vehicle['brand'] ?? '');
    final modelCtrl = TextEditingController(text: _vehicle['model'] ?? '');
    final mileageCtrl = TextEditingController(text: _currentMileage.toStringAsFixed(0));
    String selType = _vehicle['type'] ?? 'Car';
    bool saving = false;

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 16),
          Text('Edit Vehicle', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          _sheetField(ctrl: plateCtrl, hint: 'Plate Number', caps: TextCapitalization.characters),
          const SizedBox(height: 10),
          _sheetField(ctrl: brandCtrl, hint: 'Brand (e.g. Honda)'),
          const SizedBox(height: 10),
          _sheetField(ctrl: modelCtrl, hint: 'Model (e.g. Myvi)'),
          const SizedBox(height: 10),
          _sheetField(ctrl: mileageCtrl, hint: 'Current Mileage (km)', keyboard: TextInputType.number),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
            onPressed: saving ? null : () async {
              setSheet(() => saving = true);
              try {
                final newMileage = double.tryParse(mileageCtrl.text) ?? 0;
                final res = await http.patch(
                  Uri.parse('${ApiConfig.baseUrl}/vehicles/${_vehicle['id']}'),
                  headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
                  body: jsonEncode({
                    'plate_number': plateCtrl.text.trim().toUpperCase(),
                    'brand': brandCtrl.text.trim(),
                    'model': modelCtrl.text.trim(),
                    'type': selType,
                    'mileage': newMileage,
                  }),
                );
                if (res.statusCode == 200 && ctx.mounted) {
                  setState(() {
                    _vehicle['plate_number'] = plateCtrl.text.trim().toUpperCase();
                    _vehicle['brand'] = brandCtrl.text.trim();
                    _vehicle['model'] = modelCtrl.text.trim();
                    _vehicle['type'] = selType;
                    _vehicle['mileage'] = newMileage;
                    _currentMileage = newMileage;
                  });
                  Navigator.pop(ctx);
                }
              } catch (_) {}
              setSheet(() => saving = false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), elevation: 0),
            child: saving ? const CircularProgressIndicator(color: Colors.white) : Text('Save Changes', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, height: 48, child: TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx); // Close sheet first
              _deleteVehicle(); // Trigger standard delete flow
            },
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
            label: Text('Delete Vehicle', style: GoogleFonts.poppins(color: Colors.red.shade600, fontWeight: FontWeight.w600)),
          )),
        ])),
      ),
    ));
  }

  // ── Service Record Actions ──────────────────────────────────────────────────
  Future<void> _deleteServiceRecord(Map<String, dynamic> r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Record', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this ${r['service_type']} record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, elevation: 0),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final res = await http.delete(Uri.parse('${ApiConfig.baseUrl}/services/${r['id']}'));
      if (res.statusCode == 200) {
        _fetchServiceRecords();
      }
    } catch (_) {}
  }

  void _showEditServiceSheet(Map<String, dynamic> r) {
    final costCtrl = TextEditingController(text: r['cost']?.toString() ?? '0');
    final noteCtrl = TextEditingController(text: r['notes'] ?? '');
    final dateCtrl = TextEditingController(text: r['service_date'] ?? '');
    bool saving = false;

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 16),
          Text('Edit Service Record', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(r['service_type'] ?? 'Service', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () async {
              FocusScope.of(ctx).unfocus();
              final initDate = DateTime.tryParse(dateCtrl.text) ?? DateTime.now();
              final picked = await showDatePicker(
                context: ctx,
                initialDate: initDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(primary: Color(0xFF1565C0)),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                dateCtrl.text = "\${picked.year}-\${picked.month.toString().padLeft(2, '0')}-\${picked.day.toString().padLeft(2, '0')}";
              }
            },
            child: AbsorbPointer(
              child: _sheetField(ctrl: dateCtrl, hint: 'Date (YYYY-MM-DD)', keyboard: TextInputType.datetime),
            ),
          ),
          const SizedBox(height: 10),
          _sheetField(ctrl: costCtrl, hint: 'Cost (RM)', keyboard: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 10),
          _sheetField(ctrl: noteCtrl, hint: 'Notes'),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
            onPressed: saving ? null : () async {
              setSheet(() => saving = true);
              try {
                final res = await http.patch(
                  Uri.parse('${ApiConfig.baseUrl}/services/${r['id']}'),
                  headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
                  body: jsonEncode({
                    'service_date': dateCtrl.text.trim(),
                    'cost': double.tryParse(costCtrl.text) ?? 0,
                    'notes': noteCtrl.text.trim(),
                  }),
                );
                if (res.statusCode == 200 && ctx.mounted) {
                  Navigator.pop(ctx);
                  _fetchServiceRecords();
                }
              } catch (_) {}
              setSheet(() => saving = false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), elevation: 0),
            child: saving ? const CircularProgressIndicator(color: Colors.white) : Text('Save Changes', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, height: 48, child: TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteServiceRecord(r);
            },
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
            label: Text('Delete Record', style: GoogleFonts.poppins(color: Colors.red.shade600, fontWeight: FontWeight.w600)),
          )),
        ])),
      ),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMoto = _vehicle['type'] == 'Motorcycle';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(_vehicle['plate_number'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchServiceRecords,
        color: const Color(0xFF1565C0),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Vehicle Info Card ─────────────────────────────────────────
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: _showEditVehicleSheet,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isMoto ? Icons.two_wheeler : Icons.directions_car,
                          color: const Color(0xFF1565C0), size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${_vehicle['brand']} ${_vehicle['model']}',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text(_vehicle['plate_number'] ?? '',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.speed, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('${_currentMileage.toStringAsFixed(0)} km',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1565C0))),
                        ]),
                      ])),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Stats ─────────────────────────────────────────────────────
              Row(children: [
                _StatCard(label: 'Service Records', value: '${_serviceRecords.length}',
                  icon: Icons.receipt_long_outlined, color: const Color(0xFF1565C0)),
                const SizedBox(width: 12),
                _StatCard(label: 'Total Spent', value: 'RM ${_totalCost.toStringAsFixed(2)}',
                  icon: Icons.payments_outlined, color: const Color(0xFF2E7D32)),
              ]),
              const SizedBox(height: 20),

              // ── Service History ───────────────────────────────────────────
              Text('Service History',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 10),

              if (_loadingRecords)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF1565C0))))
              else if (_serviceRecords.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(children: [
                    Icon(Icons.history, size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    Text('No service records yet', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    Text('Tap + to add your first service record', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400)),
                  ]),
                )
              else
                ...List.generate(_serviceRecords.length, (i) {
                  final r = _serviceRecords[i];
                  final cost = double.tryParse(r['cost']?.toString() ?? '0') ?? 0;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showEditServiceSheet(r),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: const Color(0xFF1565C0).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.build_outlined, color: Color(0xFF1565C0), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r['service_type'] ?? 'Service', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                            Text('${r['service_date'] ?? ''} · ${r['mileage_at_service'] ?? 0} km', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                            if (r['notes'] != null && r['notes'].toString().isNotEmpty)
                              Text(r['notes'], style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ])),
                          Text('RM ${cost.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32))),
                        ]),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddServiceRecordScreen(
              vehicleId: _vehicle['id'],
              vehiclePlate: _vehicle['plate_number'] ?? '',
              vehicleType: _vehicle['type'] ?? 'Car',
              initialMileage: _currentMileage,
            )),
          );
          if (result == true) _fetchServiceRecords();
        },
        backgroundColor: const Color(0xFF1565C0),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Service', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500)),
          ])),
        ]),
      ),
    );
  }
}

Widget _sheetField({
  required TextEditingController ctrl,
  required String hint,
  TextInputType? keyboard,
  TextCapitalization caps = TextCapitalization.none,
}) {
  return TextField(
    controller: ctrl,
    keyboardType: keyboard,
    textCapitalization: caps,
    style: GoogleFonts.poppins(fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      filled: true, fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
    ),
  );
}
