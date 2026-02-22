import 'package:flutter/material.dart';

import '../models/league.dart';
import '../state/leagues_store.dart';
import 'fixtures_screen.dart';

class LeaguesScreen extends StatefulWidget {
  const LeaguesScreen({super.key, required this.store});

  final LeaguesStore store;

  @override
  State<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends State<LeaguesScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.load(active: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (_, __) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Leagues'),
            actions: [
              IconButton(
                onPressed: widget.store.loading ? null : () => widget.store.load(active: true),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _body(context),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    if (widget.store.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.store.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error:\n${widget.store.error}'),
        ),
      );
    }

    final items = widget.store.leagues;
    if (items.isEmpty) {
      return const Center(child: Text('No leagues'));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _LeagueTile(
        league: items[i],
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FixturesScreen(league: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _LeagueTile extends StatelessWidget {
  const _LeagueTile({required this.league, required this.onTap});

  final League league;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(league.name),
      subtitle: Text('${league.country ?? "-"} • provider: ${league.providerLeagueId ?? "-"}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
