import 'package:flutter/material.dart';
import '../models/app_models.dart';

class MatchAnalysisScreen extends StatelessWidget {
  final FixtureUiModel fixture;

  const MatchAnalysisScreen({
    super.key,
    required this.fixture,
  });

  String _formatKickoff(DateTime dt) {
    final local = dt.toLocal();
    return "${local.day}.${local.month}.${local.year} "
        "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("${fixture.homeTeam} vs ${fixture.awayTeam}"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          /// MATCH HEADER
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [

                  Text(
                    fixture.leagueName,
                    style: theme.textTheme.labelLarge,
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fixture.homeTeam,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text("vs"),
                      ),
                      Expanded(
                        child: Text(
                          fixture.awayTeam,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    _formatKickoff(fixture.kickoffAt),
                    style: theme.textTheme.bodySmall,
                  ),

                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          /// EXPECTED GOALS
          const Text(
            "Expected Goals",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [

              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: const [
                        Icon(Icons.home),
                        SizedBox(height: 6),
                        Text("Home xG"),
                        SizedBox(height: 6),
                        Text(
                          "1.72",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: const [
                        Icon(Icons.flight_takeoff),
                        SizedBox(height: 6),
                        Text("Away xG"),
                        SizedBox(height: 6),
                        Text(
                          "1.21",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            ],
          ),

          const SizedBox(height: 20),

          /// MARKET PROBABILITIES
          const Text(
            "Market Probabilities",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: const [

                  _MarketItem(label: "1", value: "48%"),
                  _MarketItem(label: "X", value: "26%"),
                  _MarketItem(label: "2", value: "26%"),

                  _MarketItem(label: "GG", value: "59%"),
                  _MarketItem(label: "NG", value: "41%"),
                  _MarketItem(label: "O2.5", value: "57%"),

                  _MarketItem(label: "U2.5", value: "43%"),
                  _MarketItem(label: "1X", value: "74%"),
                  _MarketItem(label: "X2", value: "52%"),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          /// TOP SCORELINES
          const Text(
            "Most Likely Scorelines",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 10),

          Card(
            child: Column(
              children: const [
                ListTile(
                  title: Text("2 - 1"),
                  trailing: Text("12.4%"),
                ),
                Divider(height: 1),
                ListTile(
                  title: Text("1 - 1"),
                  trailing: Text("11.1%"),
                ),
                Divider(height: 1),
                ListTile(
                  title: Text("1 - 0"),
                  trailing: Text("9.7%"),
                ),
                Divider(height: 1),
                ListTile(
                  title: Text("2 - 0"),
                  trailing: Text("8.9%"),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          /// MODEL PICKS
          const Text(
            "Model Picks",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [

              _PickChip(
                label: "1X2 Pick",
                value: "1",
              ),

              _PickChip(
                label: "GG",
                value: "YES",
              ),

              _PickChip(
                label: "O/U 2.5",
                value: "OVER",
              ),

              _PickChip(
                label: "HT",
                value: "X",
              ),

              _PickChip(
                label: "HT/FT",
                value: "X/1",
              ),

            ],
          ),

          const SizedBox(height: 30),

        ],
      ),
    );
  }
}

class _MarketItem extends StatelessWidget {
  final String label;
  final String value;

  const _MarketItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickChip extends StatelessWidget {
  final String label;
  final String value;

  const _PickChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(label),

          const SizedBox(height: 6),

          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),

        ],
      ),
    );
  }
}
