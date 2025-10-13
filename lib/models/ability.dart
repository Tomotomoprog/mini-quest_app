import 'package:flutter/material.dart'; // ▼▼▼ この行を追加しました ▼▼▼

class Ability {
  final String name;
  final String description;
  final IconData icon;

  Ability({
    required this.name,
    required this.description,
    required this.icon,
  });
}
