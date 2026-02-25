import 'package:flutter/material.dart';

import '../state/settings_store.dart';
import '../state/vip_store.dart';
import '../core/cache/simple_cache.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsStore settings;
  final VipStore vipStore;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.vipStore,
  });

  Future<void> _clearCache(BuildContext context) async {
    const cache = SimpleCache(ttl: Duration(minutes: 15));
    await cache.clearAll();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared')),
      );
    }
  }

  String _vipText() {
    final d = vipStore.remaining;
    if (d == Duration.zero) return 'VIP inactive';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m <= 0) return 'VIP active: ${s}s left';
    return 'VIP active: ${m}m ${s}s left';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([settings, vipStore]),
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Prediction Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),

            Text('Confidence threshold: ${(settings.threshold * 100).toStringAsFixed(0)}%'),
            Slider(
              value: settings.threshold,
              min: 0.55,
              max: 0.80,
              divisions: 25,
              label: '${(settings.threshold * 100).toStringAsFixed(0)}%',
              onChanged: settings.setThreshold,
            ),

            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Top picks per league'),
              value: settings.topPerLeague,
              onChanged: settings.setTopPerLeague,
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: settings.status,
              decoration: const InputDecoration(
                labelText: 'Default status filter',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                DropdownMenuItem(value: 'live', child: Text('Live')),
                DropdownMenuItem(value: 'finished', child: Text('Finished')),
              ],
              onChanged: (v) => settings.setStatus(v ?? 'all'),
            ),

            const SizedBox(height: 24),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.workspace_premium),
              title: const Text('VIP Status'),
              subtitle: Text(_vipText()),
              trailing: TextButton(
                onPressed: vipStore.clear,
                child: const Text('Clear VIP'),
              ),
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Remove Ads (coming soon)'),
              subtitle: const Text('Subscription / one-time purchase (next update)'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming soon')),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: const Text('Clear cache'),
              onTap: () => _clearCache(context),
            ),

            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Reset settings'),
              onTap: settings.reset,
            ),

            const SizedBox(height: 24),
            Center(
              child: Text('Sure Predict v1.0', style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        );
      },
    );
  }
}
