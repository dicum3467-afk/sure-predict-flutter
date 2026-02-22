// lib/ui/leagues_screen.dart
import 'package:flutter/material.dart';

import '../state/leagues_store.dart';
import '../services/sure_predict_service.dart';
import 'fixtures_screen.dart';

class LeaguesScreen extends StatefulWidget {
  final LeaguesStore store;

  const LeaguesScreen({super.key, required this.store});

  @override
  State<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends State<LeaguesScreen> {
  @override
  void initState() {
    super.initState();
    // încărcăm automat la intrare
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.loadLeagues();
    });
  }

  @override
  void dispose() {
    widget.store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Leagues'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: widget.store.loading ? null : widget.store.refresh,
              ),
            ],
          ),
          body: _body(context),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    final s = widget.store;

    if (s.loading && s.leagues.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (s.error != null && s.leagues.isEmpty) {
      return _ErrorView(
        error: s.error!,
        onRetry: s.loading ? null : s.refresh,
      );
    }

    final leagues = s.leagues;

    return RefreshIndicator(
      onRefresh: s.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: leagues.length + (s.error != null ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (s.error != null && i == 0) {
            return _InlineError(error: s.error!);
          }

          final idx = s.error != null ? i - 1 : i;
          final league = leagues[idx];

          return ListTile(
            title: Text(league.name),
            subtitle: Text('${league.country} • tier ${league.tier} • ${league.providerLeagueId}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FixturesScreen(
                    league: league,
                    service: widget.store.service,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 12),
            Text('Error:\n$error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String error;
  const _InlineError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.35),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded),
            const SizedBox(width: 10),
            Expanded(child: Text(error)),
          ],
        ),
      ),
    );
  }
}
