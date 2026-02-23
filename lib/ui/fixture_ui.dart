import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatKickoff(DateTime dt) {
  // Ex: 19 feb, 14:24
  return DateFormat('d MMM, HH:mm', 'en').format(dt.toLocal());
}

// status -> culoare + text
({String text, Color bg, Color fg}) statusStyle(String status) {
  final s = status.toLowerCase().trim();
  if (s == 'live' || s == 'inplay' || s == 'in_play') {
    return (text: 'LIVE', bg: Colors.red.shade600, fg: Colors.white);
  }
  if (s == 'finished' || s == 'ft') {
    return (text: 'FT', bg: Colors.green.shade700, fg: Colors.white);
  }
  // default: scheduled
  return (text: 'SCHEDULED', bg: Colors.grey.shade300, fg: Colors.black87);
}

// best bet: ia maximul dintre home/draw/away/gg/over25/under25 (dacă există)
class BestBet {
  final String label;
  final double value; // 0..1
  const BestBet(this.label, this.value);
}

BestBet? bestBetFromMap(Map p) {
  // acceptă chei diferite, după cum ai în backend
  double? d(dynamic v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

  final entries = <BestBet>[];

  final home = d(p['p_home'] ?? p['home']);
  final draw = d(p['p_draw'] ?? p['draw']);
  final away = d(p['p_away'] ?? p['away']);
  final gg = d(p['p_gg'] ?? p['gg']);
  final o25 = d(p['p_over25'] ?? p['over25'] ?? p['over_2_5']);
  final u25 = d(p['p_under25'] ?? p['under25'] ?? p['under_2_5']);

  if (home != null) entries.add(BestBet('1', home));
  if (draw != null) entries.add(BestBet('X', draw));
  if (away != null) entries.add(BestBet('2', away));
  if (gg != null) entries.add(BestBet('GG', gg));
  if (o25 != null) entries.add(BestBet('O2.5', o25));
  if (u25 != null) entries.add(BestBet('U2.5', u25));

  if (entries.isEmpty) return null;
  entries.sort((a, b) => b.value.compareTo(a.value));
  return entries.first;
}

String pct(double v) => '${(v * 100).toStringAsFixed(0)}%';
