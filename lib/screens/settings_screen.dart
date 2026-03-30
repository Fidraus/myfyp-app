import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/session_service.dart';
import '../config/api_config.dart';
import 'landing_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name = '';
  String _email = '';
  String? _avatarPath;
  int _userId = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final name   = await SessionService.getUserName();
    final email  = await SessionService.getUserEmail();
    final avatar = await SessionService.getAvatarPath();
    final userId = await SessionService.getUserId();
    setState(() {
      _name       = name ?? 'User';
      _email      = email ?? '';
      _avatarPath = avatar;
      _userId     = userId ?? 0;
    });
  }

  // ── Pick profile image from gallery ─────────────────────────────────────────
  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (picked == null) return;
      await SessionService.saveAvatarPath(picked.path);
      setState(() => _avatarPath = picked.path);
    } catch (e) {
      _showSnack('Could not open gallery. Check photo permissions in app settings.');
    }
  }

  // ── Edit Profile bottom sheet ────────────────────────────────────────────────
  void _showEditProfile() {
    final nameCtrl = TextEditingController(text: _name);
    final passCtrl = TextEditingController();
    final confCtrl = TextEditingController();
    bool obscurePass = true;
    bool obscureConf = true;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Edit Profile', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Name
                Text('Display Name', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _sheetInputDeco(hint: 'Your name', icon: Icons.person_outline),
                ),
                const SizedBox(height: 16),

                // New password
                Text('New Password', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)),
                const SizedBox(height: 6),
                TextField(
                  controller: passCtrl,
                  obscureText: obscurePass,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _sheetInputDeco(
                    hint: 'Leave blank to keep current',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: Colors.grey),
                      onPressed: () => setModal(() => obscurePass = !obscurePass),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Confirm password
                Text('Confirm Password', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)),
                const SizedBox(height: 6),
                TextField(
                  controller: confCtrl,
                  obscureText: obscureConf,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _sheetInputDeco(
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(obscureConf ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: Colors.grey),
                      onPressed: () => setModal(() => obscureConf = !obscureConf),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: saving ? null : () => _saveProfile(
                      ctx: ctx,
                      setModal: setModal,
                      nameCtrl: nameCtrl,
                      passCtrl: passCtrl,
                      confCtrl: confCtrl,
                      setSaving: (v) => setModal(() => saving = v),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text('Save Changes', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile({
    required BuildContext ctx,
    required StateSetter setModal,
    required TextEditingController nameCtrl,
    required TextEditingController passCtrl,
    required TextEditingController confCtrl,
    required Function(bool) setSaving,
  }) async {
    final newName = nameCtrl.text.trim();
    final newPass = passCtrl.text;
    final confPass = confCtrl.text;

    if (newName.isEmpty) {
      _showSnack('Name cannot be empty');
      return;
    }
    if (newPass.isNotEmpty && newPass != confPass) {
      _showSnack('Passwords do not match');
      return;
    }
    if (newPass.isNotEmpty && newPass.length < 6) {
      _showSnack('Password must be at least 6 characters');
      return;
    }

    setSaving(true);

    final body = <String, dynamic>{'name': newName};
    if (newPass.isNotEmpty) {
      body['password'] = newPass;
      body['password_confirmation'] = confPass;
    }

    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/users/$_userId'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        await SessionService.updateName(newName);
        setState(() => _name = newName);
        if (ctx.mounted) Navigator.pop(ctx);
        _showSnack('Profile updated successfully!');
      } else {
        String msg = 'Update failed';
        try {
          final b = jsonDecode(response.body);
          msg = b['message'] ?? msg;
        } catch (_) {}
        _showSnack(msg);
      }
    } catch (e) {
      _showSnack('Connection error');
    } finally {
      setSaving(false);
    }
  }

  Future<void> _logout() async {
    await SessionService.clearSession();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LandingScreen()),
        (route) => false,
      );
    }
  }

  void _showSnack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _sheetInputDeco({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = _avatarPath != null && File(_avatarPath!).existsSync();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Profile header ────────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: Column(
                  children: [
                    // Avatar with camera button
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _pickAvatar,
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.1),
                            backgroundImage: hasAvatar ? FileImage(File(_avatarPath!)) : null,
                            child: hasAvatar
                                ? null
                                : Text(
                                    _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                                    style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: const Color(0xFF1565C0)),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickAvatar,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, size: 15, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(_name, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 3),
                    Text(_email, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Account section ───────────────────────────────────────────
              _SectionHeader(label: 'Account'),
              _SectionCard(
                children: [
                  _SettingsTile(
                    icon: Icons.edit_outlined,
                    label: 'Edit Profile',
                    subtitle: 'Change name or password',
                    onTap: _showEditProfile,
                  ),
                  _SettingsTile(
                    icon: Icons.photo_camera_outlined,
                    label: 'Change Profile Photo',
                    subtitle: 'Pick from gallery',
                    onTap: _pickAvatar,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── App section ────────────────────────────────────────────────
              _SectionHeader(label: 'App'),
              _SectionCard(
                children: [
                  _SettingsTile(
                    icon: Icons.info_outline,
                    label: 'App Version',
                    trailing: Text('1.0.0', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
                  ),
                  _SettingsTile(
                    icon: Icons.directions_car_outlined,
                    label: 'About MyPomen',
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'MyPomen',
                      applicationVersion: '1.0.0',
                      applicationLegalese: 'Student Vehicle Management System',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Logout ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        content: Text('Are you sure you want to logout?', style: GoogleFonts.poppins(fontSize: 14)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Cancel', style: GoogleFonts.poppins()),
                          ),
                          ElevatedButton(
                            onPressed: () { Navigator.pop(ctx); _logout(); },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: Text('Logout', style: GoogleFonts.poppins(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade700,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text('Logout', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section header label ───────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 0.8)),
      ),
    );
  }
}

// ── Section card ───────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }
}

// ── Settings tile ──────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({required this.icon, required this.label, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF1565C0), size: 20),
      ),
      title: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500))
          : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: Colors.grey, size: 20) : null),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    );
  }
}
