// lib/ui/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/favorites_store.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fav = context.watch<FavoritesStore>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite'),
      ),
      body: fav.ids.isEmpty
          ? const Center(
              child: Text('Nu ai favorite încă'),
            )
          : ListView(
              children: fav.ids.map((id) {
                return ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text('Fixture ID: $id'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => fav.toggle(id),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
