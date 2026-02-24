import 'package:flutter/material.dart';
import '../state/favorites_store.dart';

class FavoritesScreen extends StatelessWidget {
  final FavoritesStore favoritesStore;

  const FavoritesScreen({
    super.key,
    required this.favoritesStore,
  });

  @override
  Widget build(BuildContext context) {
    final items = favoritesStore.items;

    return Scaffold(
      body: items.isEmpty
          ? const Center(child: Text('Nu ai favorite încă ⭐'))
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final f = items[index];
                final home = (f['home'] ?? '').toString();
                final away = (f['away'] ?? '').toString();
                final kickoff = (f['kickoff'] ?? '').toString();
                final status = (f['status'] ?? '').toString();

                return ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text('$home vs $away'),
                  subtitle: Text('Status: $status\nKickoff: $kickoff'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => favoritesStore.toggle(f),
                  ),
                );
              },
            ),
      floatingActionButton: items.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => favoritesStore.clear(),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Clear'),
            ),
    );
  }
}
