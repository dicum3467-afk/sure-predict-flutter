import 'package:flutter/material.dart';
import '../state/favorites_store.dart';

class FavoritesScreen extends StatelessWidget {
  final FavoritesStore store;
  const FavoritesScreen({super.key, required this.store});

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
      animation: store,
      builder: (context, _) {
        if (store.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (store.items.isEmpty) {
          return const Center(child: Text('No favorites'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: store.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final f = store.items[i];
            final home = _str(f, ['home', 'home_name'], 'Home');
            final away = _str(f, ['away', 'away_name'], 'Away');
            final id = _str(f, ['provider_fixture_id', 'providerFixtureId'], '');

            return Card(
              child: ListTile(
                title: Text('$home vs $away'),
                subtitle: id.isEmpty ? null : Text('provider_fixture_id: $id'),
              ),
            );
          },
        );
      },
    );
  }
}
