import 'package:flutter/material.dart';

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
    final api = ApiClient(); // simplu; în producție îl injectezi singleton
    final service = SurePredictService(api);
    store = FixturesStore(service);
    store.loadForLeague(widget.league.id);
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
                onPressed: store.loading ? null : () => store.loadForLeague(widget.league.id),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error:\n${store.error}'),
        ),
      );
    }

    final items = store.fixtures;
    if (items.isEmpty) {
      return const Center(child: Text('No fixtures'));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final f = items[i];
        final when = f.kickoffAt?.toLocal().toString() ?? '-';
        return ListTile(
          title: Text('${f.home} vs ${f.away}'),
          subtitle: Text('$when • ${f.status} • run: ${f.runType ?? "-"}'),
          trailing: _ProbsChip(
            pHome: f.pHome,
            pDraw: f.pDraw,
            pAway: f.pAway,
          ),
        );
      },
    );
  }
}

class _ProbsChip extends StatelessWidget {
  const _ProbsChip({this.pHome, this.pDraw, this.pAway});

  final double? pHome;
  final double? pDraw;
  final double? pAway;

  String _fmt(double? v) => v == null ? '-' : (v * 100).toStringAsFixed(0) + '%';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('H ${_fmt(pHome)}'),
        Text('D ${_fmt(pDraw)}'),
        Text('A ${_fmt(pAway)}'),
      ],
    );
  }
}
