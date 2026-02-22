import 'package:flutter/material.dart';
import '../services/sure_predict_service.dart';
import '../state/fixtures_store.dart';
import '../state/leagues_store.dart';
import 'fixtures_screen.dart';

class LeaguesScreen extends StatefulWidget {
  final LeaguesStore store;
  final SurePredictService service;

  const LeaguesScreen({
    super.key,
    required this.store,
    required this.service,
  });

  @override
  State<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends State<LeaguesScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.load();
  }

  String _str(Map<String, dynamic> m, List<String> keys, [String fallback = '']) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final store = widget.store;

        if (store.isLoading && store.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (store.error != null && store.items.isEmpty) {
          return Center(child: Text(store.error!));
        }

        return RefreshIndicator(
          onRefresh: store.load,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: store.items.length,
            itemBuilder: (context, i) {
              final l = store.items[i];
              final name = _str(l, ['name'], 'League');
              final leagueId = _str(l, ['id'], '');
              return Card(
                child: ListTile(
                  title: Text(name),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FixturesScreen(
                          leagueId: leagueId,
                          leagueName: name,
                          service: widget.service,
                          store: FixturesStore(widget.service),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
