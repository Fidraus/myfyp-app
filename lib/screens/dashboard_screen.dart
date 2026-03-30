import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../services/session_service.dart';
import 'add_vehicle_screen.dart';
import 'garage_view.dart';
import 'troubleshoot_screen.dart';
import 'workshop_locator_screen.dart';
import 'reminders_screen.dart';
import 'settings_screen.dart';
import '../config/api_config.dart';
import 'landing_screen.dart';

class DashboardScreen extends StatefulWidget {
  final bool isGuest;
  const DashboardScreen({super.key, this.isGuest = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  List<dynamic> _vehicles = [];
  bool _isLoading = true;
  String _userName = 'Guest';
  int _userId = 0;

  // Vehicle status card pager
  final PageController _pageController = PageController();
  int _currentVehiclePage = 0;

  // Map preview
  Position? _position;
  bool _mapLoading = true;
  bool _mapEnabled = false;

  // ── GPS Trip Tracker (keyed per vehicle in the slider) ─────────────────────
  // _trackerVehicleId is always synced with the current paged vehicle
  int? _trackerVehicleId;
  bool _isTracking = false;
  double _tripDistanceKm = 0;
  Position? _lastGpsPosition;
  StreamSubscription<Position>? _positionStream;
  Timer? _idleTimer;
  DateTime? _lastMovementTime;

  Map<String, dynamic>? get _trackerVehicleData => _trackerVehicleId == null
      ? null
      : _vehicles.cast<Map<String, dynamic>?>().firstWhere(
          (v) => v!['id'] == _trackerVehicleId, orElse: () => null);

  @override
  void initState() {
    super.initState();
    if (!widget.isGuest) {
      _loadSession();
    } else {
      setState(() { _isLoading = false; _userName = 'Guest'; });
    }
    _tryGetLocation();
    _pageController.addListener(() {
      if (!_pageController.hasClients) return;
      // Sync tracker vehicle to the page being viewed
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentVehiclePage && _vehicles.isNotEmpty && !_isTracking) {
        if (page >= 0 && page < _vehicles.length) {
          setState(() {
            _currentVehiclePage = page;
            _trackerVehicleId = _vehicles[page]['id'] as int?;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _positionStream?.cancel();
    _idleTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final name = await SessionService.getUserName();
    final uid  = await SessionService.getUserId();
    setState(() { _userName = name ?? 'User'; _userId = uid ?? 0; });
    _fetchVehicles();
  }

  Future<void> _fetchVehicles() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/users/$_userId/vehicles');
    try {
      final res = await http.get(url);
      if (res.statusCode == 200 && mounted) {
        final list = jsonDecode(res.body) as List;
        setState(() {
          _vehicles  = list;
          _isLoading = false;
          
          if (_vehicles.isNotEmpty) {
             if (_currentVehiclePage >= _vehicles.length) {
                 _currentVehiclePage = _vehicles.length - 1;
             }
             if (_trackerVehicleId == null || !_vehicles.any((v) => v['id'] == _trackerVehicleId)) {
                 _trackerVehicleId = _vehicles[_currentVehiclePage]['id'] as int?;
             }
          } else {
             _currentVehiclePage = 0;
             _trackerVehicleId = null;
          }
        });
      } else if (mounted) { setState(() => _isLoading = false); }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _tryGetLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _mapLoading = false); return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _mapLoading = false); return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      if (mounted) setState(() { _position = pos; _mapEnabled = true; _mapLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _mapLoading = false);
    }
  }

  // ── GPS Trip Tracker ───────────────────────────────────────────────────────
  Future<void> _stopTrip({bool isAuto = false}) async {
    await _positionStream?.cancel();
    _idleTimer?.cancel();
    _positionStream = null;
    if (!mounted) return;
    setState(() => _isTracking = false);

    final tv = _trackerVehicleData;
    if (_tripDistanceKm > 0 && tv != null) {
      final newMileage = (double.tryParse(tv['mileage']?.toString() ?? '0') ?? 0) + _tripDistanceKm;
      await _saveMileageToApi(tv['id'], newMileage);
      if (mounted) {
        final dist = _tripDistanceKm.toStringAsFixed(2);
        final prefix = isAuto ? 'Auto-Stopped! ' : '';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${prefix}Trip saved! +$dist km → ${tv['plate_number']}'),
          backgroundColor: isAuto ? Colors.orange.shade800 : Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ));
        setState(() {
          for (final v in _vehicles) {
            if (v['id'] == tv['id']) { v['mileage'] = newMileage; break; }
          }
          _tripDistanceKm = 0;
        });
      }
    } else if (mounted && isAuto) {
      _snack('Auto-stopped (no movement recorded).');
    }
  }

  Future<void> _toggleTrip() async {
    if (widget.isGuest) { _showLoginPrompt(); return; }

    if (_isTracking) {
      await _stopTrip();
    } else {
      if (_trackerVehicleId == null) {
        _snack('Add a vehicle first!'); return;
      }
      if (!await _requestLocation()) return;
      
      setState(() { 
        _isTracking = true; 
        _tripDistanceKm = 0; 
        _lastGpsPosition = null; 
        _lastMovementTime = DateTime.now(); 
      });

      // Check auto-stop every minute
      _idleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (_lastMovementTime != null && DateTime.now().difference(_lastMovementTime!).inMinutes >= 10) {
           _stopTrip(isAuto: true);
        }
      });

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      ).listen(
        (pos) {
          if (_lastGpsPosition != null) {
            final d = Geolocator.distanceBetween(
              _lastGpsPosition!.latitude, _lastGpsPosition!.longitude,
              pos.latitude, pos.longitude,
            );
            if (d > 5) {
               _lastMovementTime = DateTime.now();
               setState(() => _tripDistanceKm += d / 1000);
            }
          } else {
             _lastMovementTime = DateTime.now();
          }
          _lastGpsPosition = pos;
        },
        onError: (_) { 
          if (mounted) {
            setState(() => _isTracking = false);
            _idleTimer?.cancel();
          }
        },
      );
    }
  }

  Future<bool> _requestLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _snack('Please enable location services'); return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      _snack('Location permission denied'); return false;
    }
    return true;
  }

  Future<void> _saveMileageToApi(dynamic vId, double mileage) async {
    try {
      await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/vehicles/$vId'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'mileage': mileage}),
      );
    } catch (_) {}
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Auth guard ─────────────────────────────────────────────────────────────
  void _requireAuth(VoidCallback action) {
    if (!widget.isGuest) { action(); return; }
    _showLoginPrompt();
  }

  void _showLoginPrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 24),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: const Color(0xFF1565C0).withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF1565C0), size: 32),
            ),
            const SizedBox(height: 16),
            Text('Login Required', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('This feature is only available for registered users.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const LandingScreen()), (r) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: Text('Login / Register', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Continue as Guest', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Vehicle Status + Trip Tracker combined slider ──────────────────────────
  Widget _buildVehicleStatusSlider() {
    if (widget.isGuest) {
      return InkWell(
        onTap: _showLoginPrompt,
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_outline, size: 28, color: Colors.grey.shade400),
          const SizedBox(height: 6),
          Text('Login to view your vehicles', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
        ])),
      );
    }
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)));
    if (_vehicles.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.directions_car_outlined, size: 36, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text('No vehicles yet', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text('Add one from Quick Actions below', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400)),
      ]));
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _vehicles.length,
            onPageChanged: (i) {
              setState(() {
                _currentVehiclePage = i;
                if (!_isTracking) _trackerVehicleId = _vehicles[i]['id'] as int?;
              });
            },
            itemBuilder: (context, i) {
              final v = _vehicles[i];
              final isThisTracked = _trackerVehicleId == v['id'];
              final mileage = double.tryParse(v['mileage']?.toString() ?? '0') ?? 0;
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Vehicle info row
                    Row(
                      children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            v['type'] == 'Motorcycle' ? Icons.two_wheeler : Icons.directions_car,
                            color: const Color(0xFF1565C0), size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(v['plate_number'] ?? '-',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                          Text('${v['brand']} ${v['model']}',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Row(children: [
                            const Icon(Icons.speed, size: 13, color: Color(0xFF1565C0)),
                            const SizedBox(width: 3),
                            Text('${mileage.toStringAsFixed(0)} km',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1565C0))),
                          ]),
                          const SizedBox(height: 2),
                          Text(v['type'] ?? '', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade400)),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Integrated Trip Tracker ─────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (_isTracking && isThisTracked) ? Colors.green.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (_isTracking && isThisTracked) ? Colors.green.shade300 : Colors.grey.shade200),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: _isTracking && isThisTracked
                            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                  const SizedBox(width: 5),
                                  Text('LIVE', style: GoogleFonts.poppins(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                ]),
                                Text('+${_tripDistanceKm.toStringAsFixed(2)} km this trip',
                                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                              ])
                            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Trip Tracker', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                                Text('Tap to track your drive', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade400)),
                              ]),
                        ),
                        GestureDetector(
                          onTap: () {
                            // If another vehicle is tracking, warn
                            if (_isTracking && !isThisTracked) {
                              _snack('Stop the current trip before switching vehicles.');
                              return;
                            }
                            if (!_isTracking) _trackerVehicleId = v['id'] as int?;
                            _toggleTrip();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: (_isTracking && isThisTracked) ? Colors.red.shade600 : const Color(0xFF1565C0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(_isTracking && isThisTracked ? Icons.stop : Icons.play_arrow, color: Colors.white, size: 16),
                              const SizedBox(width: 3),
                              Text(_isTracking && isThisTracked ? 'Stop' : 'Start',
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Dot indicators — only shown when > 1 vehicle
        if (_vehicles.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_vehicles.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentVehiclePage == i ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _currentVehiclePage == i ? const Color(0xFF1565C0) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
          ),
      ],
    );
  }

  // ── Map preview ────────────────────────────────────────────────────────────
  Widget _buildMapPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Your Location', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
            Text('Tap to find workshops', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade400)),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            if (widget.isGuest) {
              _showLoginPrompt();
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkshopLocatorScreen()));
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 180,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(16)),
              child: _mapLoading
                  ? Container(color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0), strokeWidth: 2)))
                  : !_mapEnabled || _position == null
                    ? Container(color: Colors.grey.shade100, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.location_off_outlined, size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text('Location not available', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
                      ]))
                    : Stack(
                        children: [
                          FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(_position!.latitude, _position!.longitude),
                              initialZoom: 15.0,
                              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.myfyp_app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(_position!.latitude, _position!.longitude),
                                    width: 46,
                                    height: 46,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1565C0),
                                        borderRadius: BorderRadius.circular(23),
                                        border: Border.all(color: Colors.white, width: 3),
                                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                                      ),
                                      child: const Icon(Icons.my_location, color: Colors.white, size: 22),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Transparent overlay to ensure the GestureDetector above catches the tap 
                          // and doesn't let the map swallow it.
                          Positioned.fill(child: Container(color: Colors.transparent)),
                        ],
                      ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Home content ───────────────────────────────────────────────────────────
  Widget _buildHomeContent() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning,' : hour < 17 ? 'Good Afternoon,' : 'Good Evening,';

    return SingleChildScrollView(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dark Header Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(36),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(greeting, style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1)),
                              Text(_userName, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white70)),
                              if (_vehicles.isNotEmpty && _currentVehiclePage < _vehicles.length)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('${_vehicles[_currentVehiclePage]['brand']} ${_vehicles[_currentVehiclePage]['model']}', 
                                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withValues(alpha: 0.5))),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Avatar logic
                        GestureDetector(
                          onTap: () => _requireAuth(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                child: Text(
                                  widget.isGuest ? '?' : (_userName.isNotEmpty ? _userName[0].toUpperCase() : 'U'),
                                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF0F172A), width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  ],
                ),
              ),
              
              // Content Area — white card, quick actions, map
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle Card
                    _buildMainVehicleCard(),
                    const SizedBox(height: 24),

                    // Side-by-side Quick Actions
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactActionCard(
                            icon: Icons.build_circle_outlined,
                            label: 'Troubleshoot',
                            color: const Color(0xFF3B82F6),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TroubleshootScreen())),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildCompactActionCard(
                            icon: Icons.add_circle_outline,
                            label: 'Add Vehicle',
                            color: Colors.orange.shade700,
                            onTap: () => _requireAuth(() async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddVehicleScreen()));
                              _fetchVehicles();
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildMapPreview(),
                  ],
                ),
              ),
            ],
          ),
          
        ],
      ),
    );
  }

  Widget _buildCompactActionCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, 
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A), height: 1.1)),
          ],
        ),
      ),
    );
  }
  Widget _buildMainVehicleCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          // White Info Section (now the only section)
          SizedBox(
            height: 140,
            child: _buildVehicleStatusSlider(),
          ),
        ],
      ),
    );
  }



  void _onTabTapped(int i) {
    if (widget.isGuest && (i == 1 || i == 2)) {
      _showLoginPrompt();
    } else {
      setState(() => _selectedIndex = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHomeContent(),
      if (!widget.isGuest)
        GarageView(vehicles: _vehicles, isLoading: _isLoading, onRefresh: _fetchVehicles)
      else
        const Center(child: Text('Login to view Garage')),
      if (!widget.isGuest)
        const RemindersScreen()
      else
        const Center(child: Text('Login to view Schedule')),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Match the new background
      extendBody: true, // Allow body to extend behind the floating nav bar
      body: SafeArea(
        bottom: false, 
        child: IndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(icon: Icons.home_rounded, index: 0),
                _buildNavItem(icon: Icons.garage_rounded, index: 1),
                _buildNavItem(icon: Icons.calendar_month_rounded, index: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required int index}) {
    final isSelected = _selectedIndex == index;
    // Note: since our tabs only map to 3 real screens, we handle mapping index to screen via onTabTapped later
    // but here we just render icons
    return GestureDetector(
      onTap: () {
        if (index == 2) {
           _onTabTapped(2); // Routes to RemindersScreen (index 2) via the main navigation state
           return;
        }
        if (index == 3) {
           _requireAuth(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())));
           return;
        }
        _onTabTapped(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey.shade500,
          size: 24,
        ),
      ),
    );
  }
}