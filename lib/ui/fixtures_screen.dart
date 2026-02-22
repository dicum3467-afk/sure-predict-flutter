import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/league.dart';
import '../services/sure_predict_service.dart';
import '../state/fixtures_store.dart';

class FixturesScreen extends StatefulWidget {
  const FixturesScreen({super.key, required this.league});

  final League league;

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  late final FixturesStore store;

  @override
  void initState() {
    super.initState();
    final api = ApiClient();
    final service = SurePredictService(api);
    store = FixturesStore(service);
    store.loadForLeague(widget.league.id);
  }

  // ✅ FORMATARE DATĂ
  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy • HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (_, __) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.league.name),
            actions: [
              IconButton(
                onPressed: store.loading
                    ? null
                    : () => store.loadForLeague(widget.league.id),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _body(),
        );
      },
    );
  }

  Widget _body() {
    if (store.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (store.error != null) {
      return Center(child: Text('Error: ${store.error}'));
    }

    if (store.fixtures.isEmpty) {
      return const Center(child: Text('No fixtures'));
    }

    return ListView.separated(
      itemCount: store.fixtures.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final f = store.fixtures[i];
        final when = _formatDate(f.kickoffAt);

        return ListTile(
          title: Text('${f.homeTeam} vs ${f.awayTeam}'),
          subtitle: Text(
            '$when • ${f.status} • run: ${f.runType ?? '-'}',
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('H ${((f.probHome ?? 0) * 100).toStringAsFixed(0)}%'),
              Text('D ${((f.probDraw ?? 0) * 100).toStringAsFixed(0)}%'),
              Text('A ${((f.probAway ?? 0) * 100).toStringAsFixed(0)}%'),
            ],
          ),
        );
      },
    );
  }
}
