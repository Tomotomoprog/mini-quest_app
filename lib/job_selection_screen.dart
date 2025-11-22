// lib/job_selection_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/user_profile.dart';
import 'utils/progression.dart';

class JobSelectionScreen extends StatefulWidget {
  final UserProfile userProfile;

  const JobSelectionScreen({super.key, required this.userProfile});

  @override
  State<JobSelectionScreen> createState() => _JobSelectionScreenState();
}

class _JobSelectionScreenState extends State<JobSelectionScreen> {
  bool _isUpdating = false;

  // ジョブ変更処理
  Future<void> _selectJob(String jobTitle) async {
    setState(() => _isUpdating = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'selectedJob': jobTitle});

      if (mounted) {
        Navigator.of(context).pop(); // モーダルを閉じる
        Navigator.of(context).pop(); // 画面を閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('職業を「$jobTitle」に変更しました！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('変更に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ジョブ詳細モーダルを表示
  void _showJobDetail(JobDefinition job, bool isUnlocked, bool isSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _JobDetailSheet(
        job: job,
        isUnlocked: isUnlocked,
        isSelected: isSelected,
        onSelect: () => _selectJob(job.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = Progression.getLevel(widget.userProfile.xp);
    final stats = widget.userProfile.stats;

    // ランクごとにジョブを分類
    final noviceJobs =
        Progression.allJobs.where((j) => j.rank == 'Novice').toList();
    final intermediateJobs =
        Progression.allJobs.where((j) => j.rank == 'Intermediate').toList();
    final advancedJobs =
        Progression.allJobs.where((j) => j.rank == 'Advanced').toList();

    // 解放済みジョブIDセット
    final unlockedJobs =
        Progression.getUnlockedJobs(stats, level).map((j) => j.id).toSet();
    // 見習いは常に解放
    unlockedJobs.add('apprentice');

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('職業ギルド'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '初級職'),
              Tab(text: '中級職'),
              Tab(text: '上級職'),
            ],
          ),
        ),
        body: _isUpdating
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildJobGrid(noviceJobs, unlockedJobs),
                  _buildJobGrid(intermediateJobs, unlockedJobs),
                  _buildJobGrid(advancedJobs, unlockedJobs),
                ],
              ),
      ),
    );
  }

  Widget _buildJobGrid(List<JobDefinition> jobs, Set<String> unlockedJobs) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2列
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85, // カードの比率
      ),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        final isUnlocked = unlockedJobs.contains(job.id);
        final isSelected = widget.userProfile.selectedJob == job.title;

        return _JobCard(
          job: job,
          isUnlocked: isUnlocked,
          isSelected: isSelected,
          onTap: () => _showJobDetail(job, isUnlocked, isSelected),
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobDefinition job;
  final bool isUnlocked;
  final bool isSelected;
  final VoidCallback onTap;

  const _JobCard({
    required this.job,
    required this.isUnlocked,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 解放状況に応じた色設定
    final Color cardColor = isUnlocked
        ? (isSelected ? colorScheme.primaryContainer : Colors.grey.shade900)
        : Colors.black;
    final Color iconColor = isUnlocked
        ? (isSelected ? colorScheme.primary : Colors.white)
        : Colors.grey.shade700;
    final Color borderColor =
        isSelected ? colorScheme.primary : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // アイコン
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnlocked
                      ? iconColor.withOpacity(0.1)
                      : Colors.grey.shade800,
                ),
                child: Icon(
                  isUnlocked ? Progression.getJobIcon(job.title) : Icons.lock,
                  size: 32,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 12),
              // タイトル
              Text(
                isUnlocked ? job.title : '???',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isUnlocked ? Colors.white : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              // 短い説明 (未解放なら条件ヒント)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  isUnlocked ? job.description : 'Lv.${job.requiredLevel}以上...',
                  style: TextStyle(
                    fontSize: 10,
                    color: isUnlocked
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '装備中',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// 詳細モーダル
class _JobDetailSheet extends StatelessWidget {
  final JobDefinition job;
  final bool isUnlocked;
  final bool isSelected;
  final VoidCallback onSelect;

  const _JobDetailSheet({
    required this.job,
    required this.isUnlocked,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ハンドル
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ヘッダー
          Row(
            children: [
              Icon(
                isUnlocked ? Progression.getJobIcon(job.title) : Icons.lock,
                size: 48,
                color: isUnlocked ? colorScheme.primary : Colors.grey,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUnlocked ? job.title : '未解放のジョブ',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      job.rank,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),

          // ストーリー / 解放条件
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUnlocked) ...[
                    const Text(
                      'STORY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      job.story,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'UNLOCK REQUIREMENTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _RequirementRow(
                      label: 'レベル',
                      needed: job.requiredLevel.toString(),
                      icon: Icons.star,
                    ),
                    ...job.requiredStats.entries.map((e) => _RequirementRow(
                          label: e.key,
                          needed: e.value.toString(),
                          icon: Icons.bar_chart,
                        )),
                    const SizedBox(height: 16),
                    const Text(
                      '条件を満たすと、このジョブの真の力が解放されます。',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ボタン
          if (isUnlocked)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSelected ? null : onSelect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isSelected ? '装備中' : 'このジョブに転職する',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String label;
  final String needed;
  final IconData icon;

  const _RequirementRow({
    required this.label,
    required this.needed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Text(needed,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}
