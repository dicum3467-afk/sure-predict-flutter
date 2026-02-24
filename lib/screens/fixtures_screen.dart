import 'package:flutter/material.dart';
import '../services/api_client.dart';

class FixturesScreen extends StatefulWidget {
  const FixturesScreen({super.key});

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.getFixtures(runType: "initial", limit: 50, offset: 0);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ApiClient.getFixtures(runType: "initial", limit: 50, offset: 0);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fixtures"),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text("Eroare: ${snapshot.error}"),
              ),
            );
          }

          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text("Nu există meciuri încă."));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: data.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final item = data[i] as Map<String, dynamic>;

                final home = (item["home"] ?? "").toString();
                final away = (item["away"] ?? "").toString();
                final status = (item["status"] ?? "").toString();
                final kickoff = (item["kickoff_at"] ?? "").toString();

                // IMPORTANT: provider_fixture_id este string gen "api_fix_1001"
                final providerFixtureId = (item["provider_fixture_id"] ?? "").toString();

                // Probabilități
                final pHome = item["p_home"];
                final pDraw = item["p_draw"];
                final pAway = item["p_away"];

                String fmt(dynamic v) {
                  if (v == null) return "-";
                  final num? n = v is num ? v : num.tryParse(v.toString());
                  if (n == null) return "-";
                  return (n * 100).toStringAsFixed(0) + "%";
                }

                return ListTile(
                  title: Text("$home vs $away"),
                  subtitle: Text("Status: $status\nKickoff: $kickoff"),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("H: ${fmt(pHome)}"),
                      Text("D: ${fmt(pDraw)}"),
                      Text("A: ${fmt(pAway)}"),
                    ],
                  ),
                  onTap: providerFixtureId.isEmpty
                      ? null
                      : () async {
                          // exemplu: când dai tap, cerem prediction și o afișăm într-un dialog
                          try {
                            final pred = await ApiClient.getPrediction(
                              providerFixtureId: providerFixtureId,
                              runType: "initial",
                            );

                            if (!context.mounted) return;

                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text("$home vs $away"),
                                content: SingleChildScrollView(
                                  child: Text(pred.toString()),
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Eroare prediction: $e")),
                            );
                          }
                        },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
