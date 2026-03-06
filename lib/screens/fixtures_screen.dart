import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FixturesScreen extends StatefulWidget {
  const FixturesScreen({super.key});

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {

  late Future fixtures;

  @override
  void initState() {
    super.initState();
    fixtures = ApiService.getFixtures();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Sure Predict"),
      ),

      body: FutureBuilder(

        future: fixtures,

        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final matches = snapshot.data as List;

          return ListView.builder(

            itemCount: matches.length,

            itemBuilder: (context, index) {

              final match = matches[index];

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(

                  title: Text(
                      "${match["home_team"]["name"]} vs ${match["away_team"]["name"]}"),

                  subtitle: Text(match["league_name"]),

                  trailing: Text(match["status"]),

                ),
              );
            },
          );
        },
      ),
    );
  }
}
