import 'package:flutter/material.dart';
import 'models/equipment.dart';

class ArtisanWorkshopScreen extends StatefulWidget {
  const ArtisanWorkshopScreen({super.key});

  @override
  State<ArtisanWorkshopScreen> createState() => _ArtisanWorkshopScreenState();
}

class _ArtisanWorkshopScreenState extends State<ArtisanWorkshopScreen> {
  // 後々、Firestoreなどから取得するレシピデータ（今はダミー）
  final List<Equipment> _recipes = [
    Equipment(
      id: 'wood_helmet_01',
      name: '木のヘルメット',
      description: '丈夫な木材で作られた、シンプルなヘルメット。',
      icon: Icons.hdr_strong, // ヘルメットっぽいアイコン
      slot: EquipmentSlot.head,
      requiredMaterials: {'丈夫な木材': 5},
    ),
    // TODO: 他のレシピも追加
  ];

  void _craftItem(Equipment item) {
    // TODO: 素材が足りているかチェックするロジック
    // TODO: 素材を消費して、アイテムをユーザーの所持品に追加するロジック

    // 成功したと仮定してメッセージを表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name}を作成しました！'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('職人の工房'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _recipes.length,
        itemBuilder: (context, index) {
          final item = _recipes[index];
          return Card(
            child: ListTile(
              leading: Icon(item.icon, size: 40),
              title: Text(item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.description),
                  const SizedBox(height: 4),
                  // 必要な素材を表示
                  Text(
                    '必要素材: ${item.requiredMaterials.entries.map((e) => '${e.key} x${e.value}').join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: () => _craftItem(item),
                child: const Text('作成'),
              ),
            ),
          );
        },
      ),
    );
  }
}
