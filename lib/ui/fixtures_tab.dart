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
  // multi-select
  final Set<String> _selectedLeagueIds = {};

  // search
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  // expand/collapse per grup
  final Set<String> _expandedGroups = {}; // keys: country

  @override
  void initState() {
    super.initState();

    // load leagues once
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

  void _clearSelection() {
    setState(() => _selectedLeagueIds.clear());
  }

  Map<String, List<Map<String, dynamic>>> _groupByCountry(
    List<Map<String, dynamic>> leagues,
  ) {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final l in leagues) {
      final country = (l['country'] ?? 'Other').toString().trim();
      groups.putIfAbsent(country.isEmpty ? 'Other' : country, () => []).add(l);
    }

    // sort groups alphabetically, but keep "Other" last
    final entries = groups.entries.toList()
      ..sort((a, b) {
        if (a.key == 'Other' && b.key != 'Other') return 1;
        if (b.key == 'Other' && a.key != 'Other') return -1;
        return a.key.compareTo(b.key);
      });

    return {for (final e in entries) e.key: (e.value..sort(_leagueSort))};
  }

  static int _leagueSort(Map<String, dynamic> a, Map<String, dynamic> b) {
    // prefer tier (if exists) then name
    int tierA = _tryInt(a['tier']) ?? 9999;
    int tierB = _tryInt(b['tier']) ?? 9999;
    if (tierA != tierB) return tierA.compareTo(tierB);

    final nameA = (a['name'] ?? '').toString();
    final nameB = (b['name'] ?? '').toString();
    return nameA.compareTo(nameB);
  }

  static int? _tryInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
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

  void _goToFixtures() {
    final ids = _selectedLeagueIds.toList();

    // id -> name
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
    final groups = _groupByCountry(visibleLeagues);

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

            // Chips (selected)
            if (hasSelection) _SelectedChips(
              selectedIds: _selectedLeagueIds,
              leagues: allLeagues,
              onRemoveId: (id) => setState(() => _selectedLeagueIds.remove(id)),
            ),

            if (hasSelection) const SizedBox(height: 10),

            // Quick actions row
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
                  label: Text(hasSelection
                      ? 'Vezi meciuri (${_selectedLeagueIds.length})'
                      : 'Vezi meciuri'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Loading / error
            if (widget.leaguesStore.isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (widget.leaguesStore.error != null)
              Expanded(
                child: Center(
                  child: Text(
                    widget.leaguesStore.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
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
              // Grouped list
              Expanded(
                child: ListView(
                  children: [
                    for (final entry in groups.entries)
                      _CountryGroup(
                        country: entry.key,
                        leagues: entry.value,
                        expanded: _search.isNotEmpty ||
                            _expandedGroups.contains(entry.key),
                        selectedIds: _selectedLeagueIds,
                        onToggleExpand: () {
                          setState(() {
                            if (_expandedGroups.contains(entry.key)) {
                              _expandedGroups.remove(entry.key);
                            } else {
                              _expandedGroups.add(entry.key);
                            }
                          });
                        },
                        onToggleLeague: _toggleLeague,
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

class _CountryGroup extends StatelessWidget {
  final String country;
  final List<Map<String, dynamic>> leagues;
  final bool expanded;
  final Set<String> selectedIds;
  final VoidCallback onToggleExpand;
  final void Function(Map<String, dynamic> league) onToggleLeague;

  const _CountryGroup({
    required this.country,
    required this.leagues,
    required this.expanded,
    required this.selectedIds,
    required this.onToggleExpand,
    required this.onToggleLeague,
  });

  @override
  Widget build(BuildContext context) {
    final selectedInGroup = leagues.where((l) {
      final id = (l['id'] ?? '').toString();
      return selectedIds.contains(id);
    }).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            onTap: onToggleExpand,
            title: Text(country),
            subtitle: Text('${leagues.length} ligi • selectate: $selectedInGroup'),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          ),
          if (expanded)
            const Divider(height: 1),
          if (expanded)
            ...leagues.map((l) {
              final id = (l['id'] ?? '').toString();
              final name = (l['name'] ?? 'League').toString();
              final tier = (l['tier'] ?? '').toString();
              final checked = selectedIds.contains(id);

              return CheckboxListTile(
                value: checked,
                onChanged: (_) => onToggleLeague(l),
                title: Text(name),
                subtitle: Text([
                  if (tier.isNotEmpty) 'Tier $tier',
                  if (id.isNotEmpty) id,
                ].join(' • ')),
                controlAffinity: ListTileControlAffinity.trailing,
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
    // id -> name
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
