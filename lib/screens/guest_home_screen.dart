import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'troubleshoot_screen.dart';
import 'workshop_locator_screen.dart';

class GuestHomeScreen extends StatelessWidget {
  const GuestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Guest Mode', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Emergency Access', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 6),
              Text(
                'These features are available without signing in. Perfect for roadside emergencies.',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 30),

              // Troubleshoot Card
              _GuestFeatureCard(
                icon: Icons.build_circle_outlined,
                color: const Color(0xFF1565C0),
                title: 'Troubleshoot',
                subtitle: 'Get instant guidance for common vehicle problems',
                onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const TroubleshootScreen())),
              ),
              const SizedBox(height: 16),

              // Workshop Locator Card
              _GuestFeatureCard(
                icon: Icons.location_on_outlined,
                color: const Color(0xFF2E7D32),
                title: 'Find Workshop',
                subtitle: 'Locate nearby vehicle workshops using your GPS',
                onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const WorkshopLocatorScreen())),
              ),

              const Spacer(),

              // Sign in prompt
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF1565C0), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sign in to access vehicle management, service records, and reminders.',
                        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF1565C0)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Sign in button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Sign In / Register', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestFeatureCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _GuestFeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
