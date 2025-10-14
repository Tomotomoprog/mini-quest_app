import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../models/ability.dart';
import '../../growth_path_screen.dart';

class ProfileStatsTab extends StatelessWidget {
  final UserProfile userProfile;
  final List<Ability> abilities;

  const ProfileStatsTab(
      {super.key, required this.userProfile, required this.abilities});

  static const categoryColors = {
    'Life': Color(0xFF22C55E),
    'Study': Color(0xFF3B82F6),
    'Physical': Color(0xFFEF4444),
    'Social': Color(0xFFEC4899),
    'Creative': Color(0xFFA855F7),
    'Mental': Color(0xFF6366F1),
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.trending_up),
            label: const Text('成長の道へ'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const GrowthPathScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _ProgressBar(
                      label: 'Life',
                      value: userProfile.stats.life,
                      max: 10,
                      color: categoryColors['Life']!),
                  const SizedBox(height: 16),
                  _ProgressBar(
                      label: 'Study',
                      value: userProfile.stats.study,
                      max: 10,
                      color: categoryColors['Study']!),
                  const SizedBox(height: 16),
                  _ProgressBar(
                      label: 'Physical',
                      value: userProfile.stats.physical,
                      max: 10,
                      color: categoryColors['Physical']!),
                  const SizedBox(height: 16),
                  _ProgressBar(
                      label: 'Social',
                      value: userProfile.stats.social,
                      max: 10,
                      color: categoryColors['Social']!),
                  const SizedBox(height: 16),
                  _ProgressBar(
                      label: 'Creative',
                      value: userProfile.stats.creative,
                      max: 10,
                      color: categoryColors['Creative']!),
                  const SizedBox(height: 16),
                  _ProgressBar(
                      label: 'Mental',
                      value: userProfile.stats.mental,
                      max: 10,
                      color: categoryColors['Mental']!),
                ],
              ),
            ),
          ),
          if (abilities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('アビリティ', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...abilities.map((ability) => Card(
                        child: ListTile(
                          leading: Icon(ability.icon,
                              color: Theme.of(context).colorScheme.primary),
                          title: Text(ability.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(ability.description),
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;
  const _ProgressBar(
      {required this.label,
      required this.value,
      required this.max,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('$value / $max'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value / max,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
}
