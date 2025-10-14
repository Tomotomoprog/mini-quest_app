import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/user_profile.dart' as model;
import 'main.dart';

class AvatarCreationScreen extends StatefulWidget {
  const AvatarCreationScreen({super.key});

  @override
  State<AvatarCreationScreen> createState() => _AvatarCreationScreenState();
}

class _AvatarCreationScreenState extends State<AvatarCreationScreen> {
  final List<Color> _skinColors = [
    Colors.orange.shade200,
    Colors.brown.shade400,
    Colors.yellow.shade200
  ];
  final List<Color> _hairColors = [
    Colors.brown.shade800,
    Colors.black,
    Colors.yellow.shade600
  ];
  final List<String> _hairStyles = ['default', 'curly', 'straight'];

  late Color _selectedSkinColor;
  late Color _selectedHairColor;
  late String _selectedHairStyle;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedSkinColor = _skinColors.first;
    _selectedHairColor = _hairColors.first;
    _selectedHairStyle = _hairStyles.first;
  }

  Widget _buildAvatarPreview() {
    IconData getHairIcon(String style) {
      switch (style) {
        case 'curly':
          return Icons.waves;
        case 'straight':
          return Icons.straighten;
        default:
          return Icons.person;
      }
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: 80,
          backgroundColor: _selectedSkinColor,
        ),
        Positioned(
          top: 20,
          child: Icon(
            getHairIcon(_selectedHairStyle),
            color: _selectedHairColor,
            size: 100,
          ),
        ),
      ],
    );
  }

  Widget _buildPartSelector<T>({
    required String title,
    required List<T> options,
    required T selectedValue,
    required Widget Function(T) itemBuilder,
    required void Function(T) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((option) {
              return GestureDetector(
                onTap: () => onSelect(option),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedValue == option
                          ? Theme.of(context).primaryColor
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: itemBuilder(option),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _saveAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final avatar = model.Avatar(
        hairStyle: _selectedHairStyle,
        skinColor: _selectedSkinColor,
        hairColor: _selectedHairColor,
      );

      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      // ▼▼▼ 根本的な解決ロジック ▼▼▼
      if (userDoc.exists) {
        // 【既存ユーザーの場合】
        // アバター情報のみを追加・更新し、XPやステータスは完全に保持します。
        await userDocRef.update({
          'avatar': avatar.toMap(),
        });
      } else {
        // 【完全な新規ユーザーの場合】
        // アバター情報に加えて、XPとステータスの初期値を設定して新しいドキュメントを作成します。
        await userDocRef.set({
          'avatar': avatar.toMap(),
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'xp': 0, // XPを0で初期化
          'stats': {
            // statsを0で初期化
            'Life': 0,
            'Study': 0,
            'Physical': 0,
            'Social': 0,
            'Creative': 0,
            'Mental': 0,
          }
        });
      }
      // ▲▲▲ 根本的な解決ロジック ▲▲▲

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('アバターの保存に失敗しました。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アバターを作成'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildAvatarPreview(),
            const SizedBox(height: 32),
            _buildPartSelector<Color>(
              title: '肌の色',
              options: _skinColors,
              selectedValue: _selectedSkinColor,
              itemBuilder: (color) =>
                  CircleAvatar(radius: 20, backgroundColor: color),
              onSelect: (color) => setState(() => _selectedSkinColor = color),
            ),
            const SizedBox(height: 16),
            _buildPartSelector<Color>(
              title: '髪の色',
              options: _hairColors,
              selectedValue: _selectedHairColor,
              itemBuilder: (color) =>
                  CircleAvatar(radius: 20, backgroundColor: color),
              onSelect: (color) => setState(() => _selectedHairColor = color),
            ),
            const SizedBox(height: 16),
            _buildPartSelector<String>(
              title: '髪型',
              options: _hairStyles,
              selectedValue: _selectedHairStyle,
              itemBuilder: (style) => CircleAvatar(
                  radius: 20,
                  child: Icon(style == 'curly'
                      ? Icons.waves
                      : style == 'straight'
                          ? Icons.straighten
                          : Icons.person)),
              onSelect: (style) => setState(() => _selectedHairStyle = style),
            ),
            const Spacer(),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveAvatar,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('このアバターで冒険を始める'),
                  ),
          ],
        ),
      ),
    );
  }
}
