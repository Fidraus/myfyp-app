import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import '../services/session_service.dart';
import '../services/notification_service.dart';
import '../config/api_config.dart';

// ── Service type → UI color mapping ─────────────────────────────────────────
const Map<String, Color> _serviceColors = {
  'Oil Change':                 Color(0xFF1565C0),
  'Engine Oil':                 Color(0xFF1565C0),
  'Tyre Replacement':           Color(0xFF6A1B9A),
  'Brake Service':              Color(0xFFE65100),
  'Brake Pad':                  Color(0xFFE65100),
  'Engine Tune-Up':             Color(0xFF00838F),
  'Air Filter':                 Color(0xFF2E7D32),
  'Battery Replacement':        Color(0xFFF57F17),
  'Transmission Service':       Color(0xFF37474F),
  'Coolant Flush':              Color(0xFF0277BD),
  'AC Service':                 Color(0xFF00695C),
  'Full Inspection':            Color(0xFF4527A0),
  'Chain Lube':                 Color(0xFF558B2F),
  'Chain Change':               Color(0xFF8D6E63),
  'Spark Plug':                 Color(0xFFAD1457),
  'Drive Belt':                 Color(0xFF4E342E),
  'Carburetor / Throttle Body': Color(0xFF546E7A),
};

Color _colorFor(String type) => _serviceColors[type] ?? const Color(0xFF78909C);

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;

  // Calendar state
  DateTime _focusedDay  = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _selectedDay = _normalizeDate(DateTime.now());
    _loadPendingServices();
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  // ── Fetch from backend ─────────────────────────────────────────────────────
  Future<void> _loadPendingServices() async {
    setState(() => _loading = true);
    final uid = await SessionService.getUserId();
    if (uid == null) { setState(() => _loading = false); return; }

    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/users/$uid/pending-services'))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200 && mounted) {
        final raw = jsonDecode(res.body) as List;
        final list = raw.map((e) => Map<String, dynamic>.from(e)).toList();

        // Build calendar event map
        final eventMap = <DateTime, List<Map<String, dynamic>>>{};
        for (final s in list) {
          final dateStr = s['next_due_date'] as String?;
          if (dateStr == null) continue;
          final d = _normalizeDate(DateTime.parse(dateStr));
          eventMap.putIfAbsent(d, () => []).add(s);
        }

        setState(() {
          _pending = list;
          _events  = eventMap;
          _loading = false;
        });

        // Schedule notifications without awaiting (non-blocking for UI)
        _scheduleNotifications(list).catchError((e) => debugPrint('Error scheduling: $e'));
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Calendar load timed out. Please check your connection.');
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scheduleNotifications(List<Map<String, dynamic>> services) async {
    for (final s in services) {
      final dateStr = s['next_due_date'] as String?;
      if (dateStr == null) continue;
      final dueDate  = DateTime.parse(dateStr);
      final id       = (s['id'] as num).toInt();
      final title    = '🔧 ${s['service_type']} Due — ${s['plate_number']}';

      // 7 days before
      final sevenBefore = dueDate.subtract(const Duration(days: 7));
      if (sevenBefore.isAfter(DateTime.now())) {
        await NotificationService.scheduleReminder(
          id: id * 10,
          title: title,
          body: 'Service due in 7 days on ${dueDate.day}/${dueDate.month}/${dueDate.year}.',
          scheduledDate: DateTime(sevenBefore.year, sevenBefore.month, sevenBefore.day, 9, 0),
        );
      }

      // On due day
      final dueAt = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
      if (dueAt.isAfter(DateTime.now())) {
        await NotificationService.scheduleReminder(
          id: id * 10 + 1,
          title: '⚠️ $title',
          body: 'This service is due TODAY. Keep your vehicle in top shape!',
          scheduledDate: dueAt,
        );
      }
    }
  }

  // ── Mark complete ──────────────────────────────────────────────────────────
  Future<void> _markDone(Map<String, dynamic> service) async {
    final costCtrl = TextEditingController();
    final mileageCtrl = TextEditingController(text: '${service['current_mileage'] ?? 0}');
    
    bool? proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Complete Service', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter current details below:', style: GoogleFonts.poppins(fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: costCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cost (RM)',
                prefixText: 'RM ',
                filled: true, fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Color(0xFF1565C0), width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mileageCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Current Mileage',
                suffixText: 'km',
                filled: true, fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Color(0xFF1565C0), width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), elevation: 0),
            child: Text('Confirm', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;

    final id = service['id'];
    final inputCost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
    final inputMileage = double.tryParse(mileageCtrl.text.trim());

    final body = <String, dynamic>{'cost': inputCost};
    if (inputMileage != null) body['mileage'] = inputMileage;

    try {
      final res = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/services/$id/complete'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(body),
      );
      if ((res.statusCode == 200 || res.statusCode == 201) && mounted) {
        // Cancel old notifications for this service
        final intId = (id as num).toInt();
        await NotificationService.cancelReminder(intId * 10);
        await NotificationService.cancelReminder(intId * 10 + 1);
        _snack('✅ Service logged! Next schedule calculated.');
        _loadPendingServices(); // Refresh to pull accurate next schedule
      } else {
        _snack('Failed to complete. Try again.');
      }
    } catch (_) {
      _snack('Connection error.');
    }
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Calendar helpers ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) =>
      _events[_normalizeDate(day)] ?? [];

  // Navigate calendar to a specific date and select it
  void _jumpToDate(DateTime date) {
    setState(() {
      _focusedDay  = date;
      _selectedDay = _normalizeDate(date);
    });
  }

  // Show year/month picker
  Future<void> _showYearMonthPicker() async {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    int pickerYear  = _focusedDay.year;
    int pickerMonth = _focusedDay.month;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Text('Go to Month', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // Year row
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setD(() => pickerYear--)),
              Text('$pickerYear', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setD(() => pickerYear++)),
            ]),
            const SizedBox(height: 8),
            // Month grid
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.6,
              children: List.generate(12, (i) {
                final selected = (i + 1) == pickerMonth;
                return GestureDetector(
                  onTap: () => setD(() => pickerMonth = i + 1),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF1565C0) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(months[i], style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.black87)),
                  ),
                );
              }),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.poppins())),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _jumpToDate(DateTime(pickerYear, pickerMonth, 1));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text('Go', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final now       = DateTime.now();
    final overdue   = _pending.where((s) {
      final d = s['next_due_date'];
      return d != null && DateTime.parse(d).isBefore(DateTime(now.year, now.month, now.day));
    }).toList();

    final selectedEvents = _selectedDay != null ? _getEventsForDay(_selectedDay!) : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Row(children: [
                GestureDetector(
                  onTap: _showYearMonthPicker,
                  child: Row(children: [
                    Text('Service Schedule', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Icon(Icons.calendar_month_outlined, size: 18, color: Colors.grey.shade400),
                  ]),
                ),
                const Spacer(),
                if (overdue.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(20)),
                    child: Text('${overdue.length} OVERDUE',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                else
                  Text('${_pending.length} upcoming', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
              ]),
            ),
            Container(height: 1, color: Colors.grey.shade200),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF1565C0))))
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadPendingServices,
                  color: const Color(0xFF1565C0),
                  child: ListView(
                    children: [
                      // ── Calendar ───────────────────────────────────────
                      Container(
                        color: Colors.white,
                        child: TableCalendar<Map<String, dynamic>>(
                          firstDay: DateTime(now.year - 1),
                          lastDay: DateTime(now.year + 3),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                          eventLoader: _getEventsForDay,
                          calendarFormat: CalendarFormat.month,
                          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          onDaySelected: (selected, focused) {
                            setState(() { _selectedDay = selected; _focusedDay = focused; });
                          },
                          onPageChanged: (f) => setState(() => _focusedDay = f),
                          calendarStyle: CalendarStyle(
                            todayDecoration: BoxDecoration(color: const Color(0xFF1565C0).withValues(alpha: 0.15), shape: BoxShape.circle),
                            todayTextStyle: GoogleFonts.poppins(color: const Color(0xFF1565C0), fontWeight: FontWeight.bold),
                            selectedDecoration: const BoxDecoration(color: Color(0xFF1565C0), shape: BoxShape.circle),
                            selectedTextStyle: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                            defaultTextStyle: GoogleFonts.poppins(fontSize: 13),
                            weekendTextStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.red.shade400),
                            outsideTextStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade300),
                            markersMaxCount: 4,
                            markerDecoration: const BoxDecoration(color: Colors.transparent),
                          ),
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                            leftChevronIcon: const Icon(Icons.chevron_left, color: Color(0xFF1565C0)),
                            rightChevronIcon: const Icon(Icons.chevron_right, color: Color(0xFF1565C0)),
                          ),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                            weekendStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.red.shade300),
                          ),
                          // Custom marker builder for colored dots per service type
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, day, events) {
                              if (events.isEmpty) return const SizedBox.shrink();
                              return Positioned(
                                bottom: 1,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: events.take(4).map((e) => Container(
                                    width: 6, height: 6,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: _colorFor(e['service_type'] ?? ''),
                                      shape: BoxShape.circle,
                                    ),
                                  )).toList(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // ── Selected Day Events panel ──────────────────────
                      if (selectedEvents.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.event, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 6),
                                Text(
                                  '${_selectedDay!.day} ${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][_selectedDay!.month - 1]} ${_selectedDay!.year}',
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFF1565C0).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                  child: Text('${selectedEvents.length} service${selectedEvents.length > 1 ? "s" : ""}',
                                    style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF1565C0), fontWeight: FontWeight.w600)),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              ...selectedEvents.map((s) => _buildEventTile(s)),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // ── Overdue banner ─────────────────────────────────
                      if (overdue.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                            child: Row(children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text('${overdue.length} service${overdue.length > 1 ? "s" : ""} overdue! Service your vehicle soon.',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w500))),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // ── All Upcoming Services list ─────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('All Upcoming Services',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      ),
                      const SizedBox(height: 8),

                      if (_pending.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(child: Column(children: [
                            Icon(Icons.event_available, size: 54, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No upcoming services', style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade500)),
                            const SizedBox(height: 4),
                            Text('Add a service record to generate a reminder', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400)),
                          ])),
                        )
                      else
                        ...(_pending.map((s) => GestureDetector(
                          // Tap service card → jump calendar to that month
                          onTap: () {
                            final dateStr = s['next_due_date'] as String?;
                            if (dateStr != null) _jumpToDate(DateTime.parse(dateStr));
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: _buildServiceCard(s, now),
                          ),
                        ))),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Detailed tile shown in selected day panel ────────────────────────────
  Widget _buildEventTile(Map<String, dynamic> s) {
    final color  = _colorFor(s['service_type'] ?? '');
    final isMoto = (s['type'] ?? '').contains('Motorcycle');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s['service_type'] ?? '',
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87)),
          Row(children: [
            Icon(isMoto ? Icons.two_wheeler : Icons.directions_car_outlined, size: 11, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text('${s['plate_number']} · ${s['brand']} ${s['model']}',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
          ]),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Text(isMoto ? '🏍' : '🚗', style: const TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }

  // ── Full service reminder card ─────────────────────────────────────────────
  Widget _buildServiceCard(Map<String, dynamic> s, DateTime now) {
    final dateStr  = s['next_due_date'] as String?;
    final dueDate  = dateStr != null ? DateTime.parse(dateStr) : null;
    final color    = _colorFor(s['service_type'] ?? '');

    bool isOverdue = false;
    int daysLeft   = 0;
    if (dueDate != null) {
      final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
      final today = DateTime(now.year, now.month, now.day);
      daysLeft   = due.difference(today).inDays;
      isOverdue  = daysLeft < 0;
    }

    // ── Progress calculations ──
    final currentMileage = double.tryParse(s['current_mileage']?.toString() ?? '0') ?? 0;
    final targetMileage  = double.tryParse(s['next_due_mileage']?.toString() ?? '0') ?? 0;
    final lastMileage    = double.tryParse(s['last_service_mileage']?.toString() ?? '0') ?? 0;

    double mileageProgress = 0.0;
    if (targetMileage > lastMileage) {
      mileageProgress = ((currentMileage - lastMileage) / (targetMileage - lastMileage)).clamp(0.0, 1.0);
    } else if (targetMileage > 0 && lastMileage == 0) {
      // Fallback for very first entry without a prior completed service
      mileageProgress = (currentMileage / targetMileage).clamp(0.0, 1.0);
    }

    final lastDateStr = s['last_service_date'] as String?;
    final lastDate    = lastDateStr != null ? DateTime.parse(lastDateStr) : null;
    double timeProgress = 0.0;
    if (dueDate != null && lastDate != null) {
      final totalDays = dueDate.difference(lastDate).inDays;
      final daysPassed = now.difference(lastDate).inDays;
      if (totalDays > 0) {
        timeProgress = (daysPassed / totalDays).clamp(0.0, 1.0);
      }
    }

    final overallProgress = (mileageProgress > timeProgress) ? mileageProgress : timeProgress;

    return Container(
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOverdue ? Colors.red.shade300 : Colors.grey.shade200, width: isOverdue ? 1.5 : 1),
      ),
      child: Column(
        children: [
          // Top bar with service color
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: isOverdue ? Colors.red.shade500 : color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Service type + badge
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: (isOverdue ? Colors.red : color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.build_circle_outlined, color: isOverdue ? Colors.red.shade600 : color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['service_type'] ?? '', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('${s['plate_number']} · ${s['brand']} ${s['model']}',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                ])),
                _statusBadge(isOverdue, daysLeft),
              ]),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Due date row + tap hint
              if (dueDate != null)
                Row(children: [
                  Icon(Icons.calendar_month_outlined, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text('Due: ${dueDate.day} ${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][dueDate.month - 1]} ${dueDate.year}',
                    style: GoogleFonts.poppins(fontSize: 12, color: isOverdue ? Colors.red.shade700 : Colors.black87, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Icon(Icons.touch_app_outlined, size: 12, color: Colors.grey.shade300),
                  Text(' tap to view on calendar', style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey.shade400)),
                ]),

              // Mileage row
              if (targetMileage > 0) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.speed_outlined, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text('${currentMileage.toStringAsFixed(0)} / ${targetMileage.toStringAsFixed(0)} km',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                  const Spacer(),
                  Text('${(targetMileage - currentMileage > 0 ? targetMileage - currentMileage : 0).toStringAsFixed(0)} km left',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                ]),
              ],

              const SizedBox(height: 8),
              
              // Universal Progress Bar (calculates whichever is closer to due: days or mileage)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: isOverdue ? 1.0 : overallProgress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(isOverdue ? Colors.red.shade500 : color),
                ),
              ),

              const SizedBox(height: 12),

              // Done button
              SizedBox(
                width: double.infinity, height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => _markDone(s),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text('I Already Did This', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOverdue ? Colors.red.shade600 : const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool overdue, int daysLeft) {
    if (overdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(20)),
        child: Text('${-daysLeft}d OVERDUE', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
      );
    }
    if (daysLeft == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(20)),
        child: Text('DUE TODAY', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
      );
    }
    if (daysLeft <= 7) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(20)),
        child: Text('${daysLeft}d left', style: GoogleFonts.poppins(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
      child: Text('${daysLeft}d', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade700)),
    );
  }
}
