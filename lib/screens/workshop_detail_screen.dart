import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class WorkshopDetailScreen extends StatelessWidget {
  const WorkshopDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock locations for route
    final LatLng startLoc = const LatLng(3.1390, 101.6869);
    final LatLng endLoc = const LatLng(3.1490, 101.6969);
    final LatLng mid1 = const LatLng(3.1390, 101.6969);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Map (Top Half)
          Positioned(
            top: 0, left: 0, right: 0, height: MediaQuery.of(context).size.height * 0.45,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(3.1440, 101.6919),
                initialZoom: 14.5,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.uniride_app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [startLoc, mid1, endLoc],
                      color: const Color(0xFF3B82F6),
                      strokeWidth: 4,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: startLoc,
                      width: 40, height: 40,
                      child: Container(
                         decoration: BoxDecoration(color: const Color(0xFF0F172A), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                         child: const Icon(Icons.my_location, color: Colors.white, size: 18),
                      ),
                    ),
                    Marker(
                      point: endLoc,
                      width: 40, height: 40,
                      child: Container(
                         decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF3B82F6), width: 2)),
                         child: const Icon(Icons.build, color: Color(0xFF3B82F6), size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Custom App Bar Elements
          Positioned(
            top: 50, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 18), onPressed: () => Navigator.pop(context)),
                      Text('Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF0F172A))),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
                Row(
                  children: [
                     CircleAvatar(backgroundColor: Colors.white, radius: 20, child: const Icon(Icons.favorite_border, color: Color(0xFF0F172A), size: 18)),
                     const SizedBox(width: 10),
                     CircleAvatar(backgroundColor: Colors.white, radius: 20, child: const Icon(Icons.more_horiz, color: Color(0xFF0F172A), size: 18)),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Sheet Content
          Positioned(
            top: MediaQuery.of(context).size.height * 0.40,
            left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Dark Panel Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('ProFix Super Auto', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('3.5 km', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                Text('Distance', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(width: 32),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('25 Mins', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                Text('Avg. Time', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Car image overlapping the dark/light boundary
                  Positioned(
                    top: 10, right: 20,
                    child: Icon(Icons.directions_car, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                  ),

                  // White Bottom Panel
                  Positioned(
                    top: 130, left: 0, right: 0, bottom: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Overviews', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, color: Colors.grey, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('2102 Schuster Village, Satterfieldshire, Wyoming 07072',
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Detail Grid
                          Row(
                            children: [
                              Expanded(child: _buildDetailBox(Icons.bolt, 'Super charge', '250 kW')),
                              const SizedBox(width: 12),
                              Expanded(child: _buildDetailBox(Icons.electrical_services, '8/10 plug', 'Available plugs')),
                              const SizedBox(width: 12),
                              Expanded(child: _buildDetailBox(Icons.local_parking, 'Free park', 'Parking rate')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sticky Bottom Bar
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Colors.grey.shade100)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('\$60.3', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                              const SizedBox(width: 4),
                              Text('/hr', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500)),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              elevation: 0,
                            ),
                            child: Row(
                              children: [
                                Text('Directions', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                const SizedBox(width: 8),
                                const Icon(Icons.directions, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBox(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF0F172A), size: 20),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
