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
  final Set<String> _selectedLeagueIds = {};
  final Set<String> _selectedLeagueNames = {};

  @override
  void initState() {
    super.initState();

    // încarcă ligile dacă nu sunt deja
    if (widget.leaguesStore.items.isEmpty && !widget.leaguesStore.isLoading) {
      widget.leaguesStore.load().then((_) => _pickDefaults());
    } else {
      _pickDefaults();
    }
  }

  void _pickDefaults() {
    final items = widget.leaguesStore.items;
    if (items.isEmpty) return;

    // default: primele 2 ligi (poți schimba în 1 sau 3)
    final take = items.take(2);
    setState(() {
      _selectedLeagueIds
        ..clear()
        ..addAll(take.map((e) => (e['id'] ?? '').toString()).where((s) => s.isNotEmpty));
      _selectedLeagueNames
        ..clear()
        ..addAll(take.map((e) => (e['name'] ?? '').toString()).where((s) => s.isNotEmpty));
    });
  }

  void _toggleLeague(Map<String, dynamic> league) {
    final id = (league['id'] ?? '').toString();
    final name = (league['name'] ?? '').toString();
    if (id.isEmpty) return;

    setState(() {
      if (_selectedLeagueIds.contains(id)) {
        _selectedLeagueIds.remove(id);
        if (name.isNotEmpty) _selectedLeagueNames.remove(name);
      } else {
        _selectedLeagueIds.add(id);
        if (name.isNotEmpty) _selectedLeagueNames.add(name);
      }
    });
  }

  void _selectAll() {
    final items = widget.leaguesStore.items;
    setState(() {
      _selectedLeagueIds
        ..clear()
        ..addAll(items.map((e) => (e['id'] ?? '').toString()).where((s) => s.isNotEmpty));
      _selectedLeagueNames
        ..clear()
        ..addAll(items.map((e) => (e['name'] ?? '').toString()).where((s) => s.isNotEmpty));
    });
  }

  void _clearAll() {
    setState(() {
      _selectedLeagueIds.clear();
      _selectedLeagueNames.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final leagues = widget.leaguesStore.items;

    if (leagues.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fixtures')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.leaguesStore.isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: () async {
                    await widget.leaguesStore.load();
                    _pickDefaults();
                  },
                  child: const Text('Încarcă ligile'),
                ),
              if (widget.leaguesStore.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.leaguesStore.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              ],
            ],
          ),
        ),
      );
    }

    // dacă n-ai selectat nimic, arată selectorul; dacă ai selectat, arată fixtures list
    final hasSelection = _selectedLeagueIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fixtures'),
        actions: [
          IconButton(
            tooltip: 'Selectează toate',
            onPressed: _selectAll,
            icon: const Icon(Icons.select_all),
          ),
          IconButton(
            tooltip: 'Șterge selecția',
            onPressed: _clearAll,
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Chips cu selecția curentă
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedLeagueNames.isEmpty)
                    const Chip(label: Text('Nicio ligă selectată'))
                  else
                    ..._selectedLeagueNames.map((name) => Chip(label: Text(name))),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Selector de ligi
            Expanded(
              child: ListView.separated(
                itemCount: leagues.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final l = leagues[i];
                  final id = (l['id'] ?? '').toString();
                  final name = (l['name'] ?? 'League').toString();
                  final checked = _selectedLeagueIds.contains(id);

                  return ListTile(
                    title: Text(name),
                    subtitle: Text(id),
                    trailing: Checkbox(
                      value: checked,
                      onChanged: (_) => _toggleLeague(l),
                    ),
                    onTap: () => _toggleLeague(l),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Buton: vezi meciuri pentru ligi selectate
            onPressed: hasSelection
    ? () {
        final ids = _selectedLeagueIds.toList();

        // map id -> name (din store)
        final Map<String, String> namesById = {};
        for (final l in widget.leaguesStore.items) {
          final id = (l['id'] ?? '').toString();
          final name = (l['name'] ?? '').toString();
          if (id.isNotEmpty && name.isNotEmpty) {
            namesById[id] = name;
          }
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
    : null,
