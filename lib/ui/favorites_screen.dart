import 'package:flutter/material.dart';

import '../state/favorites_store.dart';
import '../state/fixtures_store.dart';
import 'fixture_tile.dart';
import 'prediction_sheet.dart';

class FavoritesScreen extends StatelessWidget {
  final FixturesStore fixturesStore;
  final FavoritesStore favoritesStore;

  const FavoritesScreen({
    super.key,
    required this.fixturesStore,
    required this.favoritesStore,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([fixturesStore, favoritesStore]),
      builder: (context, _) {
        final favIds = favoritesStore.allIds.toSet();

        final favFixtures = fixturesStore.fixtures
            .where((f) => favIds.contains(f.providerFixtureId))
            .toList();

        if (favFixtures.isEmpty) {
          return const Center(
            child: Text(
              'No favorites yet ⭐',
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          itemCount: favFixtures.length,
          itemBuilder: (context, index) {
            final f = favFixtures[index];

            return FixtureTile(
              home: f.home,
              away: f.away,
              status: f.status,
              kickoff: f.kickoff,
              prediction: f.prediction,
              fixtureId: f.providerFixtureId,
              favorites: favoritesStore,
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
        );
      },
    );
  }
}
