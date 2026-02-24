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

    if (widget.leaguesStore.items.isEmpty && !widget.leaguesStore.isLoading) {
      widget.leaguesStore.load().then((_) => _tryPickFirstLeague());
    } else {
      _tryPickFirstLeague();
    }
  }

  void _tryPickFirstLeague() {
    final items = widget.leaguesStore.items;
    if (items.isNotEmpty) {
      final first = items.first;
      setState(() {
        _leagueId = first['id']?.toString();
        _leagueName = first['name']?.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final leagues = widget.leaguesStore.items;

    if (_leagueId == null || _leagueName == null) {
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
              if (widget.leaguesStore.isLoading)
                const Center(child: CircularProgressIndicator()),

              if (widget.leaguesStore.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    widget.leaguesStore.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return FixturesScreen(
      leagueId: _leagueId!,
      leagueName: _leagueName!,
      service: widget.service,
    );
  }
}
