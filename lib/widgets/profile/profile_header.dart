import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../../utils/progression.dart';
import '../../profile_friends_list_screen.dart';

class ProfileHeader extends StatelessWidget {
  final UserProfile userProfile;
  final int level;
  final JobResult jobInfo;
  final bool isMyProfile;
  final VoidCallback onEditPicture;

  const ProfileHeader({
    super.key,
    required this.userProfile,
    required this.level,
    required this.jobInfo,
    required this.isMyProfile,
    required this.onEditPicture,
  });

  Widget _buildAvatar(BuildContext context) {
    if (userProfile.photoURL != null && userProfile.photoURL!.isNotEmpty) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: NetworkImage(userProfile.photoURL!),
      );
    }

    if (userProfile.avatar != null) {
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
              radius: 50, backgroundColor: userProfile.avatar!.skinColor),
          Positioned(
            top: 0,
            child: Icon(
              getHairIcon(userProfile.avatar!.hairStyle),
              color: userProfile.avatar!.hairColor,
              size: 60,
            ),
          ),
        ],
      );
    }

    return const CircleAvatar(
      radius: 50,
      child: Icon(Icons.person, size: 50),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              _buildAvatar(context),
              if (isMyProfile)
                Material(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: onEditPicture,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(height: 16),
          Text(userProfile.displayName ?? '名無しさん',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Text('レベル', style: Theme.of(context).textTheme.bodySmall),
                    Text(level.toString(),
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                const VerticalDivider(width: 32, thickness: 1),
                Column(
                  children: [
                    Text('ジョブ', style: Theme.of(context).textTheme.bodySmall),
                    Text(jobInfo.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
                const VerticalDivider(width: 32, thickness: 1),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('friendships')
                      .where('userIds', arrayContains: userProfile.uid)
                      .where('status', isEqualTo: 'accepted')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final friendCount = snapshot.data?.docs.length ?? 0;
                    return InkWell(
                      onTap: friendCount > 0
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ProfileFriendsListScreen(
                                    userId: userProfile.uid,
                                    userName:
                                        userProfile.displayName ?? '名無しさん',
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: Column(
                        children: [
                          Text('フレンド',
                              style: Theme.of(context).textTheme.bodySmall),
                          Text(friendCount.toString(),
                              style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
