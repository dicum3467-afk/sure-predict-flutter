import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../api/backend_api.dart";
import "../models/fixture_item.dart";

class FixturesScreen extends StatefulWidget {
  const FixturesScreen({
    super.key,
    required this.leagueId,
    this.dateFrom,
    this.dateTo,
  });

  final String leagueId; // UUID din tabela leagues
  final String? dateFrom; // YYYY-MM-DD
  final String? dateTo;   // YYYY-MM-DD

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  final _api = BackendApi();
  late Future<List<FixtureItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getFixturesByLeague(
      leagueId: widget.leagueId,
      dateFrom: widget.dateFrom,
      dateTo: widget.dateTo,
      limit: 50,
      offset: 0,
    );
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat("dd MMM, HH:mm").format(dt);
    } catch (_) {
      return iso;
    }
  }

  String _score(FixtureItem f) {
    final hg = f.homeGoals;
    final ag = f.awayGoals;
    if (hg == null || ag == null) return "-";
    return "$hg - $ag";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fixtures"),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _future = _api.getFixturesByLeague(
                  leagueId: widget.leagueId,
                  dateFrom: widget.dateFrom,
                  dateTo: widget.dateTo,
                  limit: 50,
                  offset: 0,
                );
              });
            },
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: FutureBuilder<List<FixtureItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Eroare:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(snap.error.toString()),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _future = _api.getFixturesByLeague(
                          leagueId: widget.leagueId,
                          dateFrom: widget.dateFrom,
                          dateTo: widget.dateTo,
                          limit: 50,
                          offset: 0,
                        );
                      });
                    },
                    child: const Text("Retry"),
                  )
                ],
              ),
            );
          }

          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text("Nu există meciuri în DB pentru filtrul ales."));
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final f = items[i];
              return ListTile(
                title: Text("${f.homeTeam} vs ${f.awayTeam}"),
                subtitle: Text("${_fmtDate(f.fixtureDate)} • ${f.status}"),
                trailing: Text(
                  _score(f),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
