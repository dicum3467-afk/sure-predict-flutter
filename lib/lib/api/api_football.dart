import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiFootball {
  static const _base = 'https://v3.football.api-sports.io';
  final String apiKey;

  ApiFootball(this.apiKey);

  Map<String, String> get _headers => {
        'x-apisports-key': apiKey,
      };

  Future<List<Map<String, dynamic>>> getTodayFixtures() async {
    final today = DateTime.now();
    final dateStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse('$_base/fixtures?date=$dateStr');
    final res = await http.get(uri, headers: _headers);

    if (res.statusCode != 200) return [];

    final data = json.decode(res.body) as Map<String, dynamic>;
    return (data['response'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> getPredictions(int fixtureId) async {
    final uri = Uri.parse('$_base/predictions?fixture=$fixtureId');
    final res = await http.get(uri, headers: _headers);

    if (res.statusCode != 200) return null;

    final data = json.decode(res.body) as Map<String, dynamic>;
    final resp = (data['response'] as List);
    if (resp.isEmpty) return null;

    return resp.first as Map<String, dynamic>;
  }
}
