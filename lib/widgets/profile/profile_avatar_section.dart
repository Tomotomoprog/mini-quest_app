// lib/widgets/profile/profile_avatar_section.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';

class ProfileAvatarSection extends StatefulWidget {
  final UserProfile userProfile;
  final bool isMyProfile;
  final VoidCallback onEditPicture;

  const ProfileAvatarSection({
    super.key,
    required this.userProfile,
    required this.isMyProfile,
    required this.onEditPicture,
  });

  @override
  State<ProfileAvatarSection> createState() => _ProfileAvatarSectionState();
}

class _ProfileAvatarSectionState extends State<ProfileAvatarSection> {
  List<String> _titles = [];
  bool _isLoadingTitles = true;

  static const String _defaultAvatar =
      'lib/assets/images/avatar/minarai_boy.jpg';

  @override
  void initState() {
    super.initState();
    _fetchTitles();
  }

  @override
  void didUpdateWidget(covariant ProfileAvatarSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userProfile.uid != oldWidget.userProfile.uid) {
      _fetchTitles();
    }
  }

  // ▼▼▼ 称号取得ロジック ▼▼▼
  Future<void> _fetchTitles() async {
    final profile = widget.userProfile;
    final List<String> titles = [];

    try {
      // 1. 開発者 (tomo_developer)
      // 完全に一致する場合、これ以外の称号は与えない
      if (profile.accountName == 'tomo_developer') {
        if (mounted) {
          setState(() {
            _titles = ['開発者'];
            _isLoadingTitles = false;
          });
        }
        return;
      }

      // 2. 開発協力者 (2025/11/30までに投稿があるか)
      // 期限: 2025年11月30日 23:59:59
      final deadline = DateTime(2025, 11, 30, 23, 59, 59);

      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: profile.uid)
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(deadline))
          .limit(1) // 1つでもあればOK
          .get();

      if (snapshot.docs.isNotEmpty) {
        titles.add('開発協力者');
      }

      // (3. 古参冒険者などの他の称号があればここに追加)
    } catch (e) {
      print('称号取得エラー: $e');
    }

    if (mounted) {
      setState(() {
        _titles = titles;
        _isLoadingTitles = false;
      });
    }
  }
  // ▲▲▲

  void _showEditProfileDialog(BuildContext context) {
    final nameController =
        TextEditingController(text: widget.userProfile.displayName);
    final bioController = TextEditingController(text: widget.userProfile.bio);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('プロフィールを編集'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名前'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return '名前は必須です';
                    if (value.length > 20) return '名前は20文字以内にしてください';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: bioController,
                  decoration: const InputDecoration(
                    labelText: '自己紹介',
                    hintText: 'よろしくお願いします！',
                  ),
                  maxLength: 100,
                  maxLines: 2,
                  validator: (value) {
                    if (value != null && value.length > 100)
                      return '100文字以内にしてください';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('保存'),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  try {
                    await user.updateDisplayName(nameController.text.trim());
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                      'displayName': nameController.text.trim(),
                      'bio': bioController.text.trim(),
                    });
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('プロフィールを更新しました')),
                      );
                    }
                  } catch (e) {
                    // Error handling
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvatarWidget(BuildContext context) {
    const double avatarRadius = 45;
    Widget avatarContent;
    if (widget.userProfile.photoURL != null &&
        widget.userProfile.photoURL!.isNotEmpty) {
      avatarContent = CircleAvatar(
        radius: avatarRadius,
        backgroundImage: NetworkImage(widget.userProfile.photoURL!),
      );
    } else if (widget.userProfile.avatar != null) {
      avatarContent = CircleAvatar(
        radius: avatarRadius,
        backgroundColor: widget.userProfile.avatar!.skinColor,
      );
    } else {
      avatarContent = CircleAvatar(
        radius: avatarRadius,
        backgroundColor: Colors.grey[700],
        child: Icon(Icons.person, size: avatarRadius, color: Colors.grey[400]),
      );
    }
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: avatarContent,
        ),
        if (widget.isMyProfile)
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: Theme.of(context).colorScheme.primary,
              shape: const CircleBorder(
                  side: BorderSide(color: Colors.black, width: 2)),
              elevation: 3.0,
              child: InkWell(
                onTap: widget.onEditPicture,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(6.0),
                  child: Icon(Icons.edit, color: Colors.white, size: 16),
                ),
              ),
            ),
          )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatarWidget(context),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        widget.userProfile.displayName ?? '名無しさん',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isMyProfile)
                      IconButton(
                        icon: Icon(Icons.edit_outlined,
                            color: Colors.grey[400], size: 20),
                        onPressed: () => _showEditProfileDialog(context),
                      ),
                  ],
                ),
                if (widget.userProfile.accountName != null)
                  Text(
                    '@${widget.userProfile.accountName}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[400],
                        ),
                  ),
                const SizedBox(height: 8),
                Text(
                  widget.userProfile.bio ??
                      (widget.isMyProfile ? '自己紹介を追加...' : '自己紹介はありません'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[400],
                        fontStyle: (widget.userProfile.bio == null ||
                                widget.userProfile.bio!.isEmpty)
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // ▼▼▼ 称号表示エリア ▼▼▼
                if (_titles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: _titles
                        .map((title) => _TitleChip(title: title))
                        .toList(),
                  ),
                ],
                // ▲▲▲
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleChip extends StatelessWidget {
  final String title;
  const _TitleChip({required this.title});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (title) {
      case '開発者':
        color = Colors.amber.shade600;
        icon = Icons.code_rounded;
        break;
      case '開発協力者':
        color = Colors.cyan.shade400;
        icon = Icons.group_work_outlined;
        break;
      case '古参冒険者':
        color = Colors.deepOrange.shade400;
        icon = Icons.shield_outlined;
        break;
      default:
        color = Colors.grey.shade400;
        icon = Icons.bookmark_border_rounded;
    }

    return Chip(
      avatar: Icon(icon, color: color, size: 16),
      label: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      backgroundColor: color.withOpacity(0.25),
      side: BorderSide(color: color.withOpacity(0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
