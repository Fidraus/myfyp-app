import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class TroubleshootScreen extends StatefulWidget {
  const TroubleshootScreen({super.key});

  @override
  State<TroubleshootScreen> createState() => _TroubleshootScreenState();
}

class _TroubleshootScreenState extends State<TroubleshootScreen> {
  final TextEditingController _searchController = TextEditingController();

  // KNOWLEDGE BASE — 25 issues, basic + advanced
  final List<Map<String, dynamic>> _knowledgeBase = [
    // ======================= BASIC ========================
    {
      'keyword': "Won't Start",
      'problem': "Engine won't start",
      'cause': 'Battery dead, starter motor failed, or fuel not reaching engine.',
      'solution': 'Check battery terminals. Turn on headlights — if dim, battery is dead. Try a jump start. Check fuel gauge.',
      'danger': 'High',
      'advanced': false,
    },
    {
      'keyword': 'Flat Tyre',
      'problem': 'Flat or punctured tyre',
      'cause': 'Nail/debris puncture, valve leak, or sidewall damage.',
      'solution': 'Pull over safely away from traffic. Engage hazard lights. Replace with spare tyre. Do NOT drive on a rim.',
      'danger': 'High',
      'advanced': false,
    },
    {
      'keyword': 'Overheating',
      'problem': 'Engine overheating',
      'cause': 'Low coolant level, blocked radiator, broken fan, or coolant leak.',
      'solution': 'Stop immediately! Turn off engine. Do NOT open radiator cap while hot. Wait 30+ minutes before checking coolant.',
      'danger': 'High',
      'advanced': false,
    },
    {
      'keyword': 'Brake Noise',
      'problem': 'Squeaking or grinding brakes',
      'cause': 'Worn brake pads causing metal-on-metal contact.',
      'solution': 'Visit a workshop immediately. Continuing to drive risks disc damage and total brake failure.',
      'danger': 'High',
      'advanced': false,
    },
    {
      'keyword': 'Dead Battery',
      'problem': 'Battery completely dead',
      'cause': 'Lights left on, old battery (3–5 yr), or faulty alternator.',
      'solution': 'Jump-start the car using jumper cables. If recurring, replace battery or have alternator tested.',
      'danger': 'Medium',
      'advanced': false,
    },
    {
      'keyword': 'Hot Air AC',
      'problem': 'AC blowing hot air',
      'cause': 'Refrigerant gas leaked out or compressor clutch failure.',
      'solution': 'Visit a workshop to check gas pressure. A refill may be needed. Do not ignore, especially in hot weather.',
      'danger': 'Low',
      'advanced': false,
    },
    {
      'keyword': 'White Smoke',
      'problem': 'White smoke from exhaust',
      'cause': 'Coolant leaking into engine combustion chamber.',
      'solution': 'Check oil dipstick for milky/frothy residue. If present, stop driving — this is a serious internal leak.',
      'danger': 'High',
      'advanced': false,
    },
    {
      'keyword': 'Black Smoke',
      'problem': 'Black smoke from exhaust',
      'cause': 'Engine burning too much fuel (rich mixture). Caused by dirty air filter or faulty injectors.',
      'solution': 'Replace air filter. Have fuel injectors inspected. Avoid prolonged driving.',
      'danger': 'Medium',
      'advanced': false,
    },
    {
      'keyword': 'Dim Lights',
      'problem': 'Headlights dimming',
      'cause': 'Weak battery, failing alternator, or corroded connections.',
      'solution': 'Check battery voltage with a multimeter. Have alternator output tested. Clean battery terminals.',
      'danger': 'Medium',
      'advanced': false,
    },
    {
      'keyword': 'Fuel Smell',
      'problem': 'Strong petrol or fuel smell',
      'cause': 'Fuel line leak, loose fuel cap, or carburetor issue.',
      'solution': 'Do NOT smoke or use open flame near the vehicle. Park in open area. Check fuel cap first. Inspect fuel lines at a workshop.',
      'danger': 'High',
      'advanced': false,
    },
    {
      'keyword': 'Wiper Streaks',
      'problem': 'Wipers leaving streaks',
      'cause': 'Worn wiper blade rubber or cracked blade.',
      'solution': 'Replace wiper blades. Clean windscreen thoroughly. Use wiper fluid, not plain water.',
      'danger': 'Low',
      'advanced': false,
    },
    {
      'keyword': 'Stall',
      'problem': 'Engine stalling while driving',
      'cause': 'Fuel delivery issue, dirty throttle body, or faulty idle air control valve.',
      'solution': 'Check petrol level. Clean throttle body. Have idle sensor inspected at a workshop.',
      'danger': 'Medium',
      'advanced': false,
    },
    {
      'keyword': 'Vibration',
      'problem': 'Steering wheel or car vibrating',
      'cause': 'Unbalanced tyres, worn shock absorbers, or bent rim.',
      'solution': 'Check tyre pressure and balance. Inspect rims for bends. Have shock absorbers tested.',
      'danger': 'Medium',
      'advanced': false,
    },
    {
      'keyword': 'No Power',
      'problem': 'Car feels slow / loss of power',
      'cause': 'Clogged air filter, dirty fuel injectors, or worn spark plugs.',
      'solution': 'Replace air filter. Use fuel system cleaner. Have spark plugs and injectors checked.',
      'danger': 'Low',
      'advanced': false,
    },
    {
      'keyword': 'Gear Slip',
      'problem': 'Automatic gear slipping or jerking',
      'cause': 'Low transmission fluid, worn clutch plates, or solenoid failure.',
      'solution': 'Check transmission fluid level and colour. If burnt smell or dark colour, flush required. Visit workshop promptly.',
      'danger': 'High',
      'advanced': false,
    },

    // ======================= ADVANCED ========================
    {
      'keyword': 'ABS Light',
      'problem': 'ABS warning light on dashboard',
      'cause': 'Faulty ABS wheel speed sensor, low brake fluid, or ABS module failure.',
      'solution': 'Brakes still work, but ABS may not engage during hard stops. Do not ignore. Have ABS system scanned at a workshop immediately.',
      'danger': 'High',
      'advanced': true,
    },
    {
      'keyword': 'Check Engine',
      'problem': 'Check Engine light on',
      'cause': 'Wide range of causes — from loose fuel cap to oxygen sensor, catalytic converter, or misfires.',
      'solution': 'Use an OBD-II scanner to read fault codes. A loose fuel cap can cause this; tighten it. For repeated issues, seek professional diagnosis.',
      'danger': 'Medium',
      'advanced': true,
    },
    {
      'keyword': 'Engine Knock',
      'problem': 'Knocking / pinging noise from engine',
      'cause': 'Low-octane fuel, carbon build-up, or worn connecting rod bearings.',
      'solution': 'Use the correct octane fuel as specified. If knock persists after fuelling, STOP DRIVING. This may indicate severe bearing damage.',
      'danger': 'High',
      'advanced': true,
    },
    {
      'keyword': 'Transmission Slip',
      'problem': 'Transmission slipping between gears',
      'cause': 'Worn transmission bands, low fluid, or clutch pack failure.',
      'solution': 'Avoid high-load driving. Check and top up transmission fluid. Full disassembly may be needed — requires professional inspection.',
      'danger': 'High',
      'advanced': true,
    },
    {
      'keyword': 'Power Steering',
      'problem': 'Steering feels heavy / power steering failure',
      'cause': 'Low power steering fluid, broken belt, or electronic PS motor failure.',
      'solution': 'Check and top up PS fluid. Inspect belt condition. For EPS (electric), fault code scanning is required. Avoid sharp turns at speed.',
      'danger': 'High',
      'advanced': true,
    },
    {
      'keyword': 'Head Gasket',
      'problem': 'Head gasket failure',
      'cause': 'Overheating damage causing seal between cylinder head and block to fail.',
      'solution': 'Signs: milky oil, white exhaust smoke, coolant loss, overheating. STOP DRIVING IMMEDIATELY. This is a major engine repair requiring full workshop service.',
      'danger': 'High',
      'advanced': true,
    },
    {
      'keyword': 'Electrical Short',
      'problem': 'Electrical short circuit',
      'cause': 'Damaged wiring insulation, rodent damage, or incorrect aftermarket fitting.',
      'solution': 'If you see sparks, smell burning plastic, or fuses blow repeatedly — disconnect the battery and tow the vehicle. Do not attempt self-repair.',
      'danger': 'High',
      'advanced': true,
    },
    {
      'keyword': 'Crankshaft',
      'problem': 'Crankshaft or bottom-end failure',
      'cause': 'Oil starvation, spun bearing, or metal fatigue — often from neglected oil changes.',
      'solution': 'Loud knocking or grinding at idle that worsens under load. STOP ENGINE IMMEDIATELY. Engine rebuild or replacement is required.',
      'danger': 'High',
      'advanced': true,
    },
    {
      'keyword': 'Airbag Light',
      'problem': 'Airbag / SRS warning light on',
      'cause': 'Faulty airbag sensor, clock spring failure, or low battery voltage spike.',
      'solution': 'Airbags may not deploy in a collision. Do NOT attempt to dismantle airbag components yourself — risk of accidental deployment. Requires specialist diagnostic.',
      'danger': 'High',
      'advanced': true,
    },
    {
      'keyword': 'Fuel Injector',
      'problem': 'Clogged or leaking fuel injectors',
      'cause': 'Carbon deposits from low-quality fuel or prolonged service intervals.',
      'solution': 'Symptoms: rough idle, poor mileage, misfires. Injector cleaning or ultrasonic cleaning at a workshop may help. Leaking injectors must be replaced.',
      'danger': 'Medium',
      'advanced': true,
    },
  ];

  List<Map<String, dynamic>> _filtered = [];
  bool _hasSearched = false;
  
  // AI State
  bool _isLoadingAi = false;
  Map<String, dynamic>? _aiResult;

  @override
  void initState() {
    super.initState();
    _filtered = [];
  }

  void _search(String query) {
    if (query.trim().isEmpty) {
      setState(() { _filtered = []; _hasSearched = false; _aiResult = null; });
      return;
    }
    final q = query.toLowerCase();
    final results = _knowledgeBase.where((item) {
      return item['keyword'].toString().toLowerCase().contains(q) ||
          item['problem'].toString().toLowerCase().contains(q) ||
          item['cause'].toString().toLowerCase().contains(q);
    }).toList();

    setState(() {
      _filtered = results;
      _hasSearched = true;
      _aiResult = null;
    });
  }

  Future<void> _askAi(String query) async {
    if (query.trim().isEmpty) return;
    
    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoadingAi = true;
      _hasSearched = true;
      _filtered = [];
      _aiResult = null;
    });

    // TODO: Load this from an environment variable!
    const apiKey = 'YOUR_GROQ_API_KEY_HERE';
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {
              'role': 'system',
              'content': 'You are an expert car mechanic. Analyze the user\'s issue and provide a diagnosis in pure JSON format.\n{\n  "keyword": "Short 1-2 word summary",\n  "problem": "Clear statement of the problem",\n  "cause": "Possible causes",\n  "solution": "Actionable, step-by-step solution",\n  "danger": "Low", "Medium", or "High",\n  "advanced": boolean (true if it needs professional help)\n}\nReturn ONLY JSON, no markdown formatting or extra text/backticks.'
            },
            {'role': 'user', 'content': query}
          ],
          'temperature': 0.3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        // Clean JSON string in case the model returns markdown code blocks
        final cleanJson = content.toString()
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final resultMap = jsonDecode(cleanJson);
        setState(() {
          _aiResult = resultMap;
          _aiResult!['is_ai'] = true;
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Error: ${response.statusCode}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI Error: Failed to connect. Please try again.')));
    } finally {
      if (mounted) setState(() => _isLoadingAi = false);
    }
  }

  Color _dangerColor(String level) {
    switch (level) {
      case 'High': return Colors.red;
      case 'Medium': return Colors.orange;
      case 'Low': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Troubleshoot', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: Colors.grey.shade200, height: 1)),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.poppins(fontSize: 14),
                    onChanged: _search,
                    onSubmitted: _askAi,
                    decoration: InputDecoration(
                      hintText: 'Describe issue (e.g. flat tyre)...',
                      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF1565C0)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _search('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // AI Button
                InkWell(
                  onTap: () => _askAi(_searchController.text),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.purple.shade400, Colors.deepPurple.shade600]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
          // AI Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: Colors.purple.shade50,
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 14, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Text('Tap the AI button to get advanced Groq AI diagnosis', 
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.purple.shade800, fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingAi) ...[
                    const SizedBox(height: 60),
                    Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(color: Colors.deepPurple),
                          const SizedBox(height: 16),
                          Text('AI is diagnosing your problem...', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ] else if (_aiResult != null) ...[
                    Text('AI Diagnosis', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.purple.shade700)),
                    const SizedBox(height: 12),
                    _buildResultCard(_aiResult!),
                  ] else if (!_hasSearched) ...[
                    // Quick Keywords
                    Text('Common Problems', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _knowledgeBase.where((i) => !(i['advanced'] as bool)).map((item) {
                        return ActionChip(
                          label: Text(item['keyword'], style: GoogleFonts.poppins(fontSize: 12)),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300),
                          onPressed: () {
                            _searchController.text = item['keyword'];
                            _search(item['keyword']);
                          },
                        );
                      }).toList(),
                    ),
                  ] else if (_filtered.isEmpty) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No results found in knowledge base', style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade500)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _askAi(_searchController.text),
                              icon: const Icon(Icons.auto_awesome, size: 18),
                              label: Text('Ask AI', style: GoogleFonts.poppins()),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600, foregroundColor: Colors.white),
                            )
                          ],
                        ),
                      ),
                    )
                  ] else ...[
                    Text('${_filtered.length} result(s) found', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 12),
                    ..._filtered.map((item) => _buildResultCard(item)),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.purple.shade100)),
                      child: Row(children: [
                        Expanded(child: Text('Didn\'t find what you need?', style: GoogleFonts.poppins(fontSize: 13, color: Colors.purple.shade900))),
                        ElevatedButton(
                          onPressed: () => _askAi(_searchController.text),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600, foregroundColor: Colors.white, elevation: 0),
                          child: Text('Ask AI', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _safeString(dynamic value, String fallback) {
    if (value == null) return fallback;
    if (value is List) return value.join(', ');
    return value.toString();
  }

  Widget _buildResultCard(Map<String, dynamic> item) {
    final isAdvanced = (item['advanced'] as bool?) ?? false;
    final danger = _safeString(item['danger'], 'Medium');
    final isAi = (item['is_ai'] as bool?) ?? false;

    final problemStr = _safeString(item['problem'], 'Problem Unspecified');
    final causeStr = _safeString(item['cause'], 'Unknown');
    final solutionStr = _safeString(item['solution'], 'Consult mechanic.');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isAi ? Colors.purple.shade300 : (isAdvanced ? Colors.red.shade200 : Colors.grey.shade200), width: isAi ? 1.5 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Professional warning banner (advanced only)
          if (isAdvanced)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.engineering, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ This issue requires professional diagnosis. Do not attempt self-repair.',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red.shade800),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(problemStr, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
                          if (isAi)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(4)),
                              child: Text('AI Generated', style: GoogleFonts.poppins(fontSize: 9, color: Colors.purple.shade800, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _infoRow('Why this happens:', causeStr, Icons.help_outline),
                      const SizedBox(height: 8),
                      _infoRow('What to do:', solutionStr, Icons.check_circle_outline),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Danger badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _dangerColor(danger).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _dangerColor(danger).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: _dangerColor(danger), size: 22),
                      const SizedBox(height: 4),
                      Text(danger, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: _dangerColor(danger))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
              Text(value, style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}