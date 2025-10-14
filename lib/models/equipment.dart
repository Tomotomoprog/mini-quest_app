import 'package:flutter/material.dart';

// アバターの装備品（スキン）を表すクラス
class Equipment {
  final String id;
  final String name;
  final String description;
  final IconData icon; // 装備を表現するためのアイコン（仮）
  final EquipmentSlot slot; // どの部位の装備か
  final Map<String, int> requiredMaterials; // 作成に必要な素材

  Equipment({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.slot,
    required this.requiredMaterials,
  });
}

// 装備部位
enum EquipmentSlot {
  head,
  torso,
}
