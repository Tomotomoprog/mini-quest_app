// lib/widgets/friend_selector_dialog.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';

class FriendSelectorDialog extends StatefulWidget {
  final List<String> selectedFriendIds;

  const FriendSelectorDialog({
    super.key,
    required this.selectedFriendIds,
  });

  @override
  State<FriendSelectorDialog> createState() => _FriendSelectorDialogState();
}

class _FriendSelectorDialogState extends State<FriendSelectorDialog> {
  List<UserProfile> _friends = [];
  late List<String> _tempSelectedIds;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tempSelectedIds = List.from(widget.selectedFriendIds);
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // フレンドシップを取得
      final friendships = await FirebaseFirestore.instance
          .collection('friendships')
          .where('userIds', arrayContains: currentUser.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      final friendIds = <String>[];
      for (var doc in friendships.docs) {
        final userIds = doc.data()['userIds'] as List;
        final fid = userIds.firstWhere((id) => id != currentUser.uid,
            orElse: () => null);
        if (fid != null) friendIds.add(fid);
      }

      if (friendIds.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // プロフィールを取得
      // ※フレンド数が多い場合は分割取得が必要ですが、ここでは簡易実装
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId,
              whereIn: friendIds.take(10).toList()) // 仮に10件制限
          .get();

      if (mounted) {
        setState(() {
          _friends = usersSnapshot.docs
              .map((doc) => UserProfile.fromFirestore(doc))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Friend fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('フレンドを招待'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _friends.isEmpty
                ? const Center(child: Text('フレンドがいません'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      final friend = _friends[index];
                      final isSelected = _tempSelectedIds.contains(friend.uid);
                      return CheckboxListTile(
                        title: Text(friend.displayName ?? '名無しさん'),
                        secondary: CircleAvatar(
                          backgroundImage: friend.photoURL != null
                              ? NetworkImage(friend.photoURL!)
                              : null,
                          child: friend.photoURL == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _tempSelectedIds.add(friend.uid);
                            } else {
                              _tempSelectedIds.remove(friend.uid);
                            }
                          });
                        },
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _tempSelectedIds),
          child: const Text('決定'),
        ),
      ],
    );
  }
}
