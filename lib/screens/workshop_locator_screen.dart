import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';


class WorkshopLocatorScreen extends StatefulWidget {
  const WorkshopLocatorScreen({super.key});

  @override
  State<WorkshopLocatorScreen> createState() => _WorkshopLocatorScreenState();
}

class _WorkshopLocatorScreenState extends State<WorkshopLocatorScreen> {
  Position? _position;
  bool _loading = true;
  String? _error;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() { _loading = true; _error = null; });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() { _error = 'Location services are disabled. Please enable GPS.'; _loading = false; });
      return;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        setState(() { _error = 'Location permission denied.'; _loading = false; });
        return;
      }
    }
    if (perm == LocationPermission.deniedForever) {
      setState(() { _error = 'Location permanently denied. Enable it in device Settings.'; _loading = false; });
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() { _position = pos; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Could not get location. Try again.'; _loading = false; });
    }
  }

  Future<void> _openGoogleMaps() async {
    String query;
    if (_position != null) {
      query = 'vehicle+workshop+near+${_position!.latitude},${_position!.longitude}';
    } else {
      query = 'vehicle+workshop+near+me';
    }
    final url = Uri.parse('https://www.google.com/maps/search/$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Workshop Locator', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          // Map area
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_off, size: 60, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _getCurrentLocation,
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                                child: Text('Try Again', style: GoogleFonts.poppins(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(_position!.latitude, _position!.longitude),
                          initialZoom: 14.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.uniride_app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_position!.latitude, _position!.longitude),
                                width: 50,
                                height: 50,
                                child: const Icon(Icons.location_on, color: Color(0xFF3B82F6), size: 40),
                              ),
                            ],
                          ),
                        ],
                      ),
          ),

          // Bottom Info Panel (RESTORED)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Nearest Workshop', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Finding the best service center for you...',
                          style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _openGoogleMaps,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Find Workshops Near Me', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        const SizedBox(width: 12),
                        const Icon(Icons.search, color: Colors.white),
                      ],
                    ),
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }
}
