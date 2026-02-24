import 'package:flutter/material.dart';
import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';
import 'fixtures_screen.dart';

class FixturesTab extends StatefulWidget {
  final SurePredictService service;
  final LeaguesStore leaguesStore;

  const FixturesTab({
    super.key,
    required this.service,
    required this.leaguesStore,
  });

  @override
  State<FixturesTab> createState() => _FixturesTabState();
}

class _FixturesTabState extends State<FixturesTab> {
  String? _leagueId;
  String? _leagueName;

  @override
  void initState() {
    super.initState();

    // Dacă store-ul tău are deja ligi, alegem prima.
    // Dacă nu, lasă așa și vei selecta manual din dropdown.
    _tryPickFirstLeague();
  }

  void _tryPickFirstLeague() {
    try {
      final items = (widget.leaguesStore as dynamic).items as List;
      if (items.isNotEmpty) {
        final first = items.first as Map<String, dynamic>;
        setState(() {
          _leagueId = first['id']?.toString();
          _leagueName = first['name']?.toString();
        });
      }
    } catch (_) {
      // dacă store-ul tău nu are "items", nu crăpăm
    }
  }

  @override
  Widget build(BuildContext context) {
    // dacă nu avem încă league selectat -> arătăm selector
    if (_leagueId == null || _leagueName == null) {
      // încercăm să luăm ligi din store (dacă există)
      List<Map<String, dynamic>> leagues = [];
      try {
        final items = (widget.leaguesStore as dynamic).items as List;
        leagues = items
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {}

      return Scaffold(
        appBar: AppBar(title: const Text('Fixtures')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Alege o ligă:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _leagueId,
                items: leagues
                    .map((l) => DropdownMenuItem<String>(
                          value: l['id']?.toString(),
                          child: Text(l['name']?.toString() ?? 'League'),
                        ))
                    .toList(),
                onChanged: (v) {
                  final selected = leagues.firstWhere(
                    (l) => l['id']?.toString() == v,
                    orElse: () => {},
                  );
                  setState(() {
                    _leagueId = v;
                    _leagueName = selected['name']?.toString() ?? 'League';
                  });
                },
                hint: const Text('Selectează...'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Dacă dropdown-ul e gol, înseamnă că LeaguesStore nu expune "items" '
                'sau nu încarcă ligile aici. Atunci facem tab-ul Fixtures să folosească un store separat.',
              ),
            ],
          ),
        ),
      );
    }

    // avem league -> afișăm ecranul tău existent
    return FixturesScreen(
      leagueId: _leagueId!,
      leagueName: _leagueName!,
      service: widget.service,
    );
  }
}
