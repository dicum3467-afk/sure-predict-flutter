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
  // multi select
  final Set<String> _selectedLeagueIds = {};

  // search
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  // expand/collapse
  final Set<String> _expandedCountries = {}; // key: country
  final Set<String> _expandedTiers = {}; // key: "$country|$tier"

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

  static int? _tryInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  static String _tierLabel(Map<String, dynamic> l) {
    final t = l['tier'];
    final ti = _tryInt(t);
    if (ti != null) return 'Tier $ti';

    final s = (t ?? '').toString().trim();
    if (s.isEmpty) return 'Tier ?';
    return s.toLowerCase().startsWith('tier') ? s : 'Tier $s';
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
    final Map<String, Map<String, List<Map<String, dynamic>>>> out = {};

    for (final l in leagues) {
      final countryRaw = (l['country'] ?? 'Other').toString().trim();
      final country = countryRaw.isEmpty ? 'Other' : countryRaw;

      final tier = _tierLabel(l);

      out.putIfAbsent(country, () => {});
      out[country]!.putIfAbsent(tier, () => []);
      out[country]![tier]!.add(l);
    }

    // sort inside each tier by name
    for (final country in out.keys) {
      for (final tier in out[country]!.keys) {
        out[country]![tier]!.sort((a, b) {
          final na = (a['name'] ?? '').toString();
          final nb = (b['name'] ?? '').toString();
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
      return a.compareTo(b);
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
    list.sort((a, b) {
      final ta = tierNum(a);
      final tb = tierNum(b);
      if (ta != tb) return ta.compareTo(tb);
      return a.compareTo(b);
    });
    return list;
  }

  void _goToFixtures() {
    final ids = _selectedLeagueIds.toList();

    final Map<String, String> namesById = {};
    for (final l in widget.leaguesStore.items) {
      final id = (l['id'] ?? '').toString();
      final name = (l['name'] ?? '').toString();
      if (id.isNotEmpty && name.isNotEmpty) namesById[id] = name;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FixturesScreen(
          service: widget.service,
          leagueIds: ids,
          leagueNamesById: namesById,
          title: 'Fixtures',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allLeagues = widget.leaguesStore.items;
    final visibleLeagues = _filterLeagues(allLeagues);
    final grouped = _groupCountryTier(visibleLeagues);

    final hasSelection = _selectedLeagueIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fixtures'),
        actions: [
          IconButton(
            tooltip: 'Clear selection',
            onPressed: hasSelection ? _clearSelection : null,
            icon: const Icon(Icons.clear_all),
          ),
        ],
      ),
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

            if (hasSelection)
              _SelectedChips(
                selectedIds: _selectedLeagueIds,
                leagues: allLeagues,
                onRemoveId: (id) =>
                    setState(() => _selectedLeagueIds.remove(id)),
              ),

            if (hasSelection) const SizedBox(height: 10),

            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: visibleLeagues.isEmpty
                      ? null
                      : () => _selectAllVisible(visibleLeagues),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Select all'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: hasSelection ? _clearSelection : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: hasSelection ? _goToFixtures : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    hasSelection
                        ? 'Vezi meciuri (${_selectedLeagueIds.length})'
                        : 'Vezi meciuri',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (widget.leaguesStore.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (widget.leaguesStore.error != null)
              Expanded(
                child: Center(
                  child: Text(
                    widget.leaguesStore.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              )
            else if (visibleLeagues.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Nu există ligi pentru filtrul curent.'),
                ),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    for (final country in _sortedCountries(grouped.keys))
                      _CountryCard(
                        country: country,
                        tiers: grouped[country]!,
                        isCountryExpanded: _expandedCountries.contains(country) ||
                            (_search.isNotEmpty &&
                                country.toLowerCase().contains(_search)),
                        expandedTiers: _expandedTiers,
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
  final Set<String> expandedTiers; // "$country|$tier"
  final Set<String> selectedIds;

  final VoidCallback onToggleCountry;
  final void Function(String tierKey) onToggleTier;
  final void Function(Map<String, dynamic> league) onToggleLeague;

  final List<String> Function(Iterable<String>) tierSorter;

  const _CountryCard({
    required this.country,
    required this.tiers,
    required this.isCountryExpanded,
    required this.expandedTiers,
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
            subtitle: Text('$total ligi • selectate: $selected'),
            trailing:
                Icon(isCountryExpanded ? Icons.expand_less : Icons.expand_more),
          ),
          if (isCountryExpanded) const Divider(height: 1),

          if (isCountryExpanded)
            ...tierSorter(tiers.keys).map((tierLabel) {
              final tierKey = '$country|$tierLabel';
              final expanded = expandedTiers.contains(tierKey);
              final list = tiers[tierLabel]!;
              final selInTier = _selectedCountInTier(list);

              return Column(
                children: [
                  ListTile(
                    dense: true,
                    onTap: () => onToggleTier(tierKey),
                    title: Text(tierLabel),
                    subtitle: Text('${list.length} ligi • selectate: $selInTier'),
                    trailing: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                    ),
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
    final Map<String, String> namesById = {
      for (final l in leagues)
        (l['id'] ?? '').toString(): (l['name'] ?? 'League').toString(),
    };

    final selectedList = selectedIds.toList()
      ..sort((a, b) => (namesById[a] ?? a).compareTo(namesById[b] ?? b));

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
