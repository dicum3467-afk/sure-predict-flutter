import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';
import '../screens/fixtures_screen.dart';

class FixturesTab extends StatefulWidget {
  final SurePredictService service;
  final LeaguesStore leaguesStore;

  const FixturesTab({
    super.key,
    required this.service,
    required this.leaguesStore,
  });

  @override
  State<FixturesTab> createState() => _FixturesTabState();
}

class _FixturesTabState extends State<FixturesTab> {
  // Multi-select
  final Set<String> _selectedLeagueIds = <String>{};

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  // Expand states
  final Set<String> _expandedCountries = <String>{}; // "England"
  final Set<String> _expandedTiers = <String>{}; // "England|Tier 1"

  @override
  void initState() {
    super.initState();

    if (widget.leaguesStore.items.isEmpty && !widget.leaguesStore.isLoading) {
      widget.leaguesStore.load();
    }

    _searchCtrl.addListener(() {
      setState(() => _search = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------- helpers ----------------

  static int? _tryInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  static String _tierLabel(Map<String, dynamic> l) {
    final raw = l['tier'];
    final ti = _tryInt(raw);
    if (ti != null) return 'Tier $ti';
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return 'Tier ?';
    if (s.toLowerCase().startsWith('tier')) return s;
    return 'Tier $s';
  }

  List<Map<String, dynamic>> _filterLeagues(List<Map<String, dynamic>> leagues) {
    if (_search.isEmpty) return leagues;

    bool matches(Map<String, dynamic> l) {
      final name = (l['name'] ?? '').toString().toLowerCase();
      final country = (l['country'] ?? '').toString().toLowerCase();
      final tier = (l['tier'] ?? '').toString().toLowerCase();
      final id = (l['id'] ?? '').toString().toLowerCase();

      return name.contains(_search) ||
          country.contains(_search) ||
          tier.contains(_search) ||
          id.contains(_search);
    }

    return leagues.where(matches).toList();
  }

  /// country -> tierLabel -> leagues
  Map<String, Map<String, List<Map<String, dynamic>>>> _groupCountryTier(
    List<Map<String, dynamic>> leagues,
  ) {
    final out = <String, Map<String, List<Map<String, dynamic>>>>{};

    for (final l in leagues) {
      final countryRaw = (l['country'] ?? 'Other').toString().trim();
      final country = countryRaw.isEmpty ? 'Other' : countryRaw;

      final tier = _tierLabel(l);

      out.putIfAbsent(country, () => <String, List<Map<String, dynamic>>>{});
      out[country]!.putIfAbsent(tier, () => <Map<String, dynamic>>[]);
      out[country]![tier]!.add(l);
    }

    // sortare ligile în tier după nume
    for (final c in out.keys) {
      for (final t in out[c]!.keys) {
        out[c]![t]!.sort((a, b) {
          final na = (a['name'] ?? '').toString().toLowerCase();
          final nb = (b['name'] ?? '').toString().toLowerCase();
          return na.compareTo(nb);
        });
      }
    }

    return out;
  }

  List<String> _sortedCountries(Iterable<String> countries) {
    final list = countries.toList();
    list.sort((a, b) {
      if (a == 'Other' && b != 'Other') return 1;
      if (b == 'Other' && a != 'Other') return -1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return list;
  }

  List<String> _sortedTiers(Iterable<String> tiers) {
    int tierNum(String s) {
      final m = RegExp(r'(\d+)').firstMatch(s);
      if (m == null) return 9999;
      return int.tryParse(m.group(1)!) ?? 9999;
    }

    final list = tiers.toList();
    list.sort((a, b) => tierNum(a).compareTo(tierNum(b)));
    return list;
  }

  // ---------------- selection actions ----------------

  void _toggleLeague(Map<String, dynamic> league) {
    final id = (league['id'] ?? '').toString();
    if (id.isEmpty) return;

    setState(() {
      if (_selectedLeagueIds.contains(id)) {
        _selectedLeagueIds.remove(id);
      } else {
        _selectedLeagueIds.add(id);
      }
    });
  }

  void _selectAllVisible(List<Map<String, dynamic>> visibleLeagues) {
    setState(() {
      for (final l in visibleLeagues) {
        final id = (l['id'] ?? '').toString();
        if (id.isNotEmpty) _selectedLeagueIds.add(id);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedLeagueIds.clear());

  Map<String, String> _leagueNamesById() {
    final Map<String, String> out = {};
    for (final l in widget.leaguesStore.items) {
      final id = (l['id'] ?? '').toString();
      final name = (l['name'] ?? '').toString();
      if (id.isNotEmpty && name.isNotEmpty) out[id] = name;
    }
    return out;
  }

  void _goToFixtures() {
    final ids = _selectedLeagueIds.toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FixturesScreen(
          service: widget.service,
          leagueIds: ids, // ✅ dacă e gol => ALL leagues (service nu trimite league_ids)
          leagueNamesById: _leagueNamesById(),
          title: ids.isEmpty ? 'Fixtures (All leagues)' : 'Fixtures (${ids.length} leagues)',
        ),
      ),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final allLeagues = widget.leaguesStore.items;
    final visibleLeagues = _filterLeagues(allLeagues);
    final grouped = _groupCountryTier(visibleLeagues);

    final hasSelection = _selectedLeagueIds.isNotEmpty;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Caută ligă / țară / tier / id...',
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _searchCtrl.clear(),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Selected chips
            if (hasSelection)
              _SelectedChips(
                selectedIds: _selectedLeagueIds,
                leagues: allLeagues,
                onRemoveId: (id) => setState(() => _selectedLeagueIds.remove(id)),
              ),

            if (hasSelection) const SizedBox(height: 10),

            // Actions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: visibleLeagues.isEmpty ? null : () => _selectAllVisible(visibleLeagues),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Select all visible'),
                ),
                OutlinedButton.icon(
                  onPressed: hasSelection ? _clearSelection : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
                FilledButton.icon(
                  // ✅ ALL leagues default: chiar dacă n-ai selectat nimic, e OK
                  onPressed: _goToFixtures,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(hasSelection ? 'Vezi meciuri (${_selectedLeagueIds.length})' : 'Vezi meciuri (All)'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Content
            if (widget.leaguesStore.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (widget.leaguesStore.error != null)
              Expanded(
                child: Center(
                  child: Text(
                    widget.leaguesStore.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (visibleLeagues.isEmpty)
              const Expanded(child: Center(child: Text('Nu există ligi pentru filtrul curent.')))
            else
              Expanded(
                child: ListView(
                  children: [
                    for (final country in _sortedCountries(grouped.keys))
                      _CountryCard(
                        country: country,
                        tiers: grouped[country]!,
                        isCountryExpanded: _search.isNotEmpty || _expandedCountries.contains(country),
                        expandedTierKeys: _expandedTiers,
                        selectedIds: _selectedLeagueIds,
                        onToggleCountry: () {
                          setState(() {
                            if (_expandedCountries.contains(country)) {
                              _expandedCountries.remove(country);
                            } else {
                              _expandedCountries.add(country);
                            }
                          });
                        },
                        onToggleTier: (tierKey) {
                          setState(() {
                            if (_expandedTiers.contains(tierKey)) {
                              _expandedTiers.remove(tierKey);
                            } else {
                              _expandedTiers.add(tierKey);
                            }
                          });
                        },
                        onToggleLeague: _toggleLeague,
                        tierSorter: _sortedTiers,
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CountryCard extends StatelessWidget {
  final String country;
  final Map<String, List<Map<String, dynamic>>> tiers; // tierLabel -> leagues

  final bool isCountryExpanded;
  final Set<String> expandedTierKeys;
  final Set<String> selectedIds;

  final VoidCallback onToggleCountry;
  final void Function(String tierKey) onToggleTier;
  final void Function(Map<String, dynamic> league) onToggleLeague;

  final List<String> Function(Iterable<String> tiers) tierSorter;

  const _CountryCard({
    required this.country,
    required this.tiers,
    required this.isCountryExpanded,
    required this.expandedTierKeys,
    required this.selectedIds,
    required this.onToggleCountry,
    required this.onToggleTier,
    required this.onToggleLeague,
    required this.tierSorter,
  });

  int _selectedCountInCountry() {
    int c = 0;
    for (final list in tiers.values) {
      for (final l in list) {
        final id = (l['id'] ?? '').toString();
        if (selectedIds.contains(id)) c++;
      }
    }
    return c;
  }

  int _totalCountInCountry() {
    int c = 0;
    for (final list in tiers.values) {
      c += list.length;
    }
    return c;
  }

  int _selectedCountInTier(List<Map<String, dynamic>> list) {
    int c = 0;
    for (final l in list) {
      final id = (l['id'] ?? '').toString();
      if (selectedIds.contains(id)) c++;
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalCountInCountry();
    final selected = _selectedCountInCountry();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            onTap: onToggleCountry,
            title: Text(country),
            subtitle: Text('$total ligi · selectate: $selected'),
            trailing: Icon(isCountryExpanded ? Icons.expand_less : Icons.expand_more),
          ),
          if (isCountryExpanded) const Divider(height: 1),

          if (isCountryExpanded)
            ...tierSorter(tiers.keys).map((tierLabel) {
              final tierKey = '$country|$tierLabel';
              final expanded = expandedTierKeys.contains(tierKey);
              final list = tiers[tierLabel] ?? [];
              final selInTier = _selectedCountInTier(list);

              return Column(
                children: [
                  ListTile(
                    dense: true,
                    onTap: () => onToggleTier(tierKey),
                    title: Text(tierLabel),
                    subtitle: Text('${list.length} ligi · selectate: $selInTier'),
                    trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  ),
                  if (expanded) const Divider(height: 1),
                  if (expanded)
                    ...list.map((l) {
                      final id = (l['id'] ?? '').toString();
                      final name = (l['name'] ?? 'League').toString();
                      final checked = selectedIds.contains(id);

                      return CheckboxListTile(
                        value: checked,
                        onChanged: (_) => onToggleLeague(l),
                        title: Text(name),
                        subtitle: Text(id),
                        controlAffinity: ListTileControlAffinity.trailing,
                      );
                    }),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _SelectedChips extends StatelessWidget {
  final Set<String> selectedIds;
  final List<Map<String, dynamic>> leagues;
  final void Function(String id) onRemoveId;

  const _SelectedChips({
    required this.selectedIds,
    required this.leagues,
    required this.onRemoveId,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, String> namesById = {};
    for (final l in leagues) {
      final id = (l['id'] ?? '').toString();
      final name = (l['name'] ?? 'League').toString();
      if (id.isNotEmpty) namesById[id] = name;
    }

    final selectedList = selectedIds.toList()
      ..sort((a, b) => (namesById[a] ?? a).toLowerCase().compareTo((namesById[b] ?? b).toLowerCase()));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in selectedList)
          InputChip(
            label: Text(namesById[id] ?? id),
            onDeleted: () => onRemoveId(id),
          ),
      ],
    );
  }
}
