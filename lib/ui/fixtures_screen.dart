import 'package:flutter/material.dart';
import '../state/fixtures_store.dart';
import 'fixture_tile.dart';
import 'prediction_sheet.dart';

class FixturesScreen extends StatefulWidget {
  final FixturesStore store;
  final String title;

  const FixturesScreen({
    super.key,
    required this.store,
    required this.title,
  });

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.loadInitial();
  }

  Future<void> _onRefresh() async {
    await widget.store.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: store.refresh,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          if (store.isLoading && store.fixtures.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (store.error != null && store.fixtures.isEmpty) {
            return Center(child: Text(store.error!));
          }

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: store.fixtures.length + 1,
              itemBuilder: (context, index) {
                // ===== FOOTER (LOAD MORE)
                if (index == store.fixtures.length) {
                  if (store.isLoadingMore) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (!store.hasMore) {
                    return const SizedBox(height: 40);
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    child: OutlinedButton.icon(
                      onPressed: store.loadMore,
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Load more'),
                    ),
                  );
                }

                // ===== ITEM
                final f = store.fixtures[index];

                return FixtureTile(
                  home: f.home,
                  away: f.away,
                  status: f.status,
                  kickoff: f.kickoff,
                  prediction: f.prediction,
                  onTap: () {
                    if (f.prediction == null) return;

                    showPredictionSheet(
                      context,
                      home: f.home,
                      away: f.away,
                      providerFixtureId: f.providerFixtureId,
                      prediction: f.prediction!,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
