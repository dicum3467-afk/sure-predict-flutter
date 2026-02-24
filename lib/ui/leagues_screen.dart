import 'package:flutter/material.dart';
import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';

class LeaguesScreen extends StatelessWidget {
  final SurePredictService service;
  final LeaguesStore leaguesStore;

  const LeaguesScreen({
    super.key,
    required this.service,
    required this.leaguesStore,
  });

  @override
  Widget build(BuildContext context) {
    final leagues = leaguesStore.items;

    return RefreshIndicator(
      onRefresh: leaguesStore.refresh,
      child: leaguesStore.isLoading
          ? const Center(child: CircularProgressIndicator())
          : leagues.isEmpty
              ? const Center(child: Text('Nu există ligi.'))
              : ListView.separated(
                  itemCount: leagues.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final l = leagues[index];
                    final name = (l['name'] ?? 'League').toString();
                    final country = (l['country'] ?? '').toString();
                    final id = (l['id'] ?? '').toString();

                    return ListTile(
                      title: Text(name),
                      subtitle: Text('$country • id=$id'),
                      leading: const Icon(Icons.public),
                    );
                  },
                ),
    );
  }
}
