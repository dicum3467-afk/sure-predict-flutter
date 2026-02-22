import 'package:flutter/material.dart';

class FavoritesScreen extends StatelessWidget {
  /// Lista de favorite ca Map-uri (de ex. ce ai salvat din fixtures).
  /// Dacă la tine vine din altă parte, păstrezi ideea: e List<Map<String,dynamic>>.
  final List<Map<String, dynamic>> favorites;

  const FavoritesScreen({super.key, required this.favorites});

  String _str(Map<String, dynamic> m, List<String> keys, [String fallback = '']) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  num? _num(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is num) return v;
      final parsed = num.tryParse(v.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  Map<String, dynamic>? _map(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is Map<String, dynamic>) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Favorites')),
        body: const Center(child: Text('No favorites')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: favorites.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final f = favorites[i];

          final home = _str(f, ['home', 'home_name', 'homeTeam', 'home_team'], 'Home');
          final away = _str(f, ['away', 'away_name', 'awayTeam', 'away_team'], 'Away');

          final providerFixtureId = _str(
            f,
            ['provider_fixture_id', 'providerFixtureId', 'fixture_id', 'fixtureId'],
            '',
          );

          final prediction = _map(f, ['prediction']);
          final pHome = prediction == null ? null : _num(prediction, ['p_home', 'home', 'homeWin', 'home_win']);
          final pDraw = prediction == null ? null : _num(prediction, ['p_draw', 'draw']);
          final pAway = prediction == null ? null : _num(prediction, ['p_away', 'away', 'awayWin', 'away_win']);

          return Card(
            child: ListTile(
              title: Text('$home vs $away'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (providerFixtureId.isNotEmpty) Text('provider_fixture_id: $providerFixtureId'),
                  if (prediction != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '1: ${pHome?.toStringAsFixed(0) ?? '-'}  '
                        'X: ${pDraw?.toStringAsFixed(0) ?? '-'}  '
                        '2: ${pAway?.toStringAsFixed(0) ?? '-'}',
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
