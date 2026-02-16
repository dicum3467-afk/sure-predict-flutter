
import 'package:flutter/material.dart';
import '../api/api_football.dart';
import '../l10n/l10n.dart';
import '../models/fixture.dart';

class MatchScreen extends StatefulWidget {
  final ApiFootball api;
  final FixtureLite fixture;

  const MatchScreen({
    super.key,
    required this.api,
    required this.fixture,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  bool loading = true;
  Map<String, dynamic>? pred;

  @override
  void initState() {
    super.initState();
    _loadPred();
  }

  Future<void> _loadPred() async {
    setState(() => loading = true);
    final p = await widget.api.getPredictions(widget.fixture.id);
    setState(() {
      pred = p;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.fixture.home} - ${widget.fixture.away}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? Text(t.t('loading'))
            : pred == null
                ? const Text('Predictions not available')
                : Column(
                    children: [
                      Text(t.t('predictions'),
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 20),
                      Text(pred.toString()),
                    ],
                  ),
      ),
    );
  }
}
