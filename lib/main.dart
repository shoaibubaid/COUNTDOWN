import 'dart:async';
import 'dart:convert';
import 'dart:ui'; // for ImageFilter (glass blur)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.indigo,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Countdown Timers',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.interTextTheme(base.textTheme),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.25,
            color: Colors.black87,
          ),
        ),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const TimersPage(),
    );
  }
}

/* ===================== Data Model ===================== */

class CountdownItem {
  final String id;
  final String label;
  final DateTime target;

  CountdownItem({required this.id, required this.label, required this.target});

  Duration remaining() {
    final diff = target.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'target': target.toIso8601String(),
      };

  static CountdownItem fromJson(Map<String, dynamic> j) => CountdownItem(
        id: j['id'] as String,
        label: j['label'] as String,
        target: DateTime.parse(j['target'] as String),
      );
}

/* ===================== Home Page ===================== */

class TimersPage extends StatefulWidget {
  const TimersPage({super.key});
  @override
  State<TimersPage> createState() => _TimersPageState();
}

class _TimersPageState extends State<TimersPage> {
  final List<CountdownItem> _timers = [];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {}); // repaint every second
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /* ---------- Persistence ---------- */

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('timers') ?? [];
    final items = raw
        .map((s) => CountdownItem.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    setState(() {
      _timers
        ..clear()
        ..addAll(items);
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _timers.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList('timers', raw);
  }

  /* ---------- Actions ---------- */

  Future<void> _addTimer() async {
    final res = await showDialog<_NewTimerResult>(
      context: context,
      builder: (_) => const _NewTimerDialog(),
    );
    if (res == null) return;
    final item = CountdownItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: res.label.trim().isEmpty ? 'Untitled' : res.label.trim(),
      target: res.dateTime,
    );
    setState(() => _timers.add(item));
    _save();
  }

  void _deleteTimer(String id) {
    setState(() => _timers.removeWhere((t) => t.id == id));
    _save();
  }

  String _fmt2(int n) => n.toString().padLeft(2, '0');

  /* ---------- UI ---------- */

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // subtle premium gradient background
        const _BGGradient(),
        Scaffold(
          appBar: AppBar(title: const Text('Countdown')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addTimer,
            label: const Text('Add Timer'),
            icon: const Icon(Icons.add),
          ),
          body: SafeArea(
            child: _timers.isEmpty
                ? Center(
                    child: GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No timers yet.\nTap “Add Timer” to create one.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: _timers.length,
                    itemBuilder: (context, i) {
                      final t = _timers[i];
                      final rem = t.remaining();
                      final days = rem.inDays;
                      final hours = rem.inHours % 24;
                      final minutes = rem.inMinutes % 60;
                      final seconds = rem.inSeconds % 60;

                      return Dismissible(
                        key: ValueKey(t.id),
                        background: _swipeBG(alignment: Alignment.centerLeft),
                        secondaryBackground:
                            _swipeBG(alignment: Alignment.centerRight),
                        onDismissed: (_) => _deleteTimer(t.id),
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        t.label,
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.25,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      onPressed: () => _deleteTimer(t.id),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    UnitBox(label: "DAYS", value: days.toString()),
                                    UnitBox(label: "HRS", value: _fmt2(hours)),
                                    UnitBox(label: "MIN", value: _fmt2(minutes)),
                                    UnitBox(label: "SEC", value: _fmt2(seconds)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "Target: ${t.target.year}-${_fmt2(t.target.month)}-${_fmt2(t.target.day)} "
                                  "${_fmt2(t.target.hour)}:${_fmt2(t.target.minute)}",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                if (rem == Duration.zero)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      "Target reached",
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _swipeBG({required Alignment alignment}) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 96,
            color: Colors.red.withOpacity(0.85),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete, color: Colors.white),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================== Reusable Widgets ===================== */

class UnitBox extends StatelessWidget {
  final String label;
  final String value;
  const UnitBox({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.black54,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _BGGradient extends StatelessWidget {
  const _BGGradient();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.9, -1.0),
          end: Alignment(1.0, 1.0),
          colors: [
            Color(0xFFE3ECFF),
            Color(0xFFD6E6FF),
            Color(0xFFF3E7FF),
            Color(0xFFFFF1F7),
          ],
        ),
      ),
    );
  }
}

/* ===================== Add Dialog ===================== */

class _NewTimerDialog extends StatefulWidget {
  const _NewTimerDialog();

  @override
  State<_NewTimerDialog> createState() => _NewTimerDialogState();
}

class _NewTimerDialogState extends State<_NewTimerDialog> {
  final _labelCtrl = TextEditingController();
  DateTime _target = DateTime.now().add(const Duration(days: 30));

  String _fmt2(int n) => n.toString().padLeft(2, '0');

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _target.isBefore(now) ? now : _target,
      firstDate: DateTime(now.year),
      lastDate: DateTime(now.year + 50),
    );
    if (pickedDate == null) return;

    final initialTime = TimeOfDay(hour: _target.hour, minute: _target.minute);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (pickedTime == null) return;

    setState(() {
      _target = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('New Countdown',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelCtrl,
            decoration: InputDecoration(
              labelText: 'Label (e.g., Trip to Berlin)',
              labelStyle: GoogleFonts.inter(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Target date & time', style: GoogleFonts.inter()),
            subtitle: Text(
              "${_target.year}-${_fmt2(_target.month)}-${_fmt2(_target.day)} "
              "${_fmt2(_target.hour)}:${_fmt2(_target.minute)}",
              style: GoogleFonts.inter(color: Colors.black54),
            ),
            trailing: FilledButton(
              onPressed: _pickDateTime,
              child: const Text('Pick'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              _NewTimerResult(_labelCtrl.text, _target),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _NewTimerResult {
  final String label;
  final DateTime dateTime;
  _NewTimerResult(this.label, this.dateTime);
}
