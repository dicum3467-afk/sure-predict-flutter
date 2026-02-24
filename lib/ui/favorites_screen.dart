import 'package:flutter/material.dart';
import '../services/sure_predict_service.dart';
import '../state/favorites_store.dart';

class FavoritesScreen extends StatelessWidget {
  final SurePredictService service;
  final FavoritesStore favoritesStore;

  const FavoritesScreen({
    super.key,
    required this.service,
    required this.favoritesStore,
  });

  @override
  Widget build(BuildContext context) {
    final items = favoritesStore.items;

    if (items.isEmpty) {
      return const Center(
        child: Text('Nu ai favorite încă ⭐'),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final f = items[index];

        final home = (f['home'] ?? '').toString();
        final away = (f['away'] ?? '').toString();
        final kickoff = (f['kickoff'] ?? '').toString();

        return ListTile(
          leading: const Icon(Icons.star, color: Colors.amber),
          title: Text('$home vs $away'),
          subtitle: Text(kickoff),
        );
      },
    );
  }
}
