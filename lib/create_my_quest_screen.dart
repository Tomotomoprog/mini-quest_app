// lib/create_my_quest_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/user_profile.dart' as model;
import 'widgets/friend_selector_dialog.dart';

class CreateMyQuestScreen extends StatefulWidget {
  const CreateMyQuestScreen({super.key});

  @override
  State<CreateMyQuestScreen> createState() => _CreateMyQuestScreenState();
}

class _CreateMyQuestScreenState extends State<CreateMyQuestScreen> {
  final _titleController = TextEditingController();
  final _motivationController = TextEditingController();
  final _scheduleController = TextEditingController();
  final _minimumStepController = TextEditingController();
  final _rewardController = TextEditingController();

  final _categories = [
    "Life",
    "Study",
    "Physical",
    "Social",
    "Creative",
    "Mental"
  ];
  String _selectedCategory = "Life";
  String _questType = 'personal';
  List<String> _invitedFriendIds = [];

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  model.UserProfile? _currentUserProfile;
  bool _isUserDataLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _motivationController.dispose();
    _scheduleController.dispose();
    _minimumStepController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isUserDataLoading = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && mounted) {
        setState(() {
          _currentUserProfile = model.UserProfile.fromFirestore(userDoc);
          _isUserDataLoading = false;
        });
      } else {
        setState(() => _isUserDataLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isUserDataLoading = false);
    }
  }

  Future<void> _selectFriends() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => FriendSelectorDialog(
        selectedFriendIds: _invitedFriendIds,
      ),
    );
    if (result != null) {
      setState(() {
        _invitedFriendIds = result;
      });
    }
  }

  Future<void> _createMyQuest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentUserProfile == null) return;

    final title = _titleController.text.trim();
    final motivation = _motivationController.text.trim();
    final schedule = _scheduleController.text.trim();
    final minimumStep = _minimumStepController.text.trim();
    final reward = _rewardController.text.trim();

    if (title.isEmpty ||
        motivation.isEmpty ||
        _startDate == null ||
        _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('必須項目（タイトル、意気込み、期間）を入力してください。')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final allParticipants = [user.uid, ..._invitedFriendIds];

      final docRef =
          await FirebaseFirestore.instance.collection('my_quests').add({
        'uid': user.uid,
        'userName': _currentUserProfile!.displayName ?? '名無しさん',
        'userPhotoURL': _currentUserProfile!.photoURL,
        'title': title,
        'motivation': motivation,
        'category': _selectedCategory,
        'startDate': DateFormat('yyyy-MM-dd').format(_startDate!),
        'endDate': DateFormat('yyyy-MM-dd').format(_endDate!),
        'schedule': schedule,
        'minimumStep': minimumStep,
        'reward': reward,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'type': _questType,
        'participantIds': allParticipants,
      });

      if (_invitedFriendIds.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final friendId in _invitedFriendIds) {
          final notifRef =
              FirebaseFirestore.instance.collection('notifications').doc();
          batch.set(notifRef, {
            'type': 'quest_invite',
            'fromUserId': user.uid,
            'fromUserName': _currentUserProfile!.displayName ?? '名無しさん',
            'fromUserAvatar': _currentUserProfile!.photoURL,
            'targetUserId': friendId,
            'questId': docRef.id,
            'questTitle': title,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
        await batch.commit();
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      print('作成エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('作成に失敗しました。')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // ▼▼▼ リッチなヘルプ画面を表示するメソッド ▼▼▼
  void _showRichHelp(String sectionKey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 画面いっぱい使えるようにする
      backgroundColor: Colors.transparent,
      builder: (context) => _HelpContentSheet(sectionKey: sectionKey),
    );
  }
  // ▲▲▲

  // ヘッダービルダ (keyを受け取るように変更)
  Widget _buildSectionHeader(String title, IconData icon, String sectionKey) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20, color: Colors.grey),
            // ▼▼▼ 変更: リッチヘルプを表示 ▼▼▼
            onPressed: () => _showRichHelp(sectionKey),
            // ▲▲▲
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('長期目標の設定')),
      body: _isUserDataLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ここは、あなたの人生を豊かにする『長期的な目標』を設計する場所です。単なるToDoリストではなく、ワクワクする冒険の地図をここに描きましょう。',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // --- クエストの種類 ---
                  _buildSectionHeader('クエストの種類', Icons.category, 'type'),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'personal',
                          label: Text('ソロ'),
                          icon: Icon(Icons.person)),
                      ButtonSegment(
                          value: 'friend',
                          label: Text('フレンド'),
                          icon: Icon(Icons.group)),
                      ButtonSegment(
                          value: 'battle',
                          label: Text('バトル'),
                          icon: Icon(Icons.emoji_events)),
                    ],
                    selected: {_questType},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _questType = newSelection.first;
                      });
                    },
                  ),
                  if (_questType != 'personal') ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _selectFriends,
                      icon: const Icon(Icons.person_add),
                      label: Text('フレンドを招待 (${_invitedFriendIds.length}人選択中)'),
                    ),
                    if (_questType == 'battle')
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '※ 努力時間や記録回数で順位を競います！',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],

                  // --- 基本設定 ---
                  _buildSectionHeader('基本設定', Icons.flag, 'basic'),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                        labelText: 'クエスト名 (目標)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                        labelText: 'カテゴリ', border: OutlineInputBorder()),
                    items: _categories.map((String category) {
                      return DropdownMenuItem<String>(
                          value: category, child: Text(category));
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCategory = val!),
                  ),

                  // --- Why ---
                  _buildSectionHeader('Why (動機)', Icons.psychology, 'why'),
                  TextField(
                    controller: _motivationController,
                    decoration: const InputDecoration(
                        labelText: 'なぜ達成したいですか？', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),

                  // --- 習慣化の仕組み ---
                  _buildSectionHeader('習慣化の仕組み', Icons.build, 'habit'),
                  TextField(
                    controller: _scheduleController,
                    decoration: InputDecoration(
                      labelText: 'いつ、どこでやりますか？',
                      hintText: '例: 朝起きて水を飲んだら、リビングで',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _minimumStepController,
                    decoration: InputDecoration(
                      labelText: '最低目標 (2分ルール)',
                      hintText: '例: 参考書を開く、靴を履く',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _rewardController,
                    decoration: InputDecoration(
                      labelText: '自分へのご褒美',
                      hintText: '例: 好きな動画を見る',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                  ),

                  // --- 期間 ---
                  _buildSectionHeader('期間', Icons.date_range, 'duration'),
                  Row(
                    children: [
                      Expanded(
                          child: OutlinedButton.icon(
                        onPressed: () => _selectDate(context, true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_startDate == null
                            ? '開始日'
                            : DateFormat('yyyy/MM/dd').format(_startDate!)),
                      )),
                      const SizedBox(width: 16),
                      const Text('〜'),
                      const SizedBox(width: 16),
                      Expanded(
                          child: OutlinedButton.icon(
                        onPressed: () => _selectDate(context, false),
                        icon: const Icon(Icons.event),
                        label: Text(_endDate == null
                            ? '終了日'
                            : DateFormat('yyyy/MM/dd').format(_endDate!)),
                      )),
                    ],
                  ),

                  const SizedBox(height: 40),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _createMyQuest,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('この内容で冒険を始める',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

// ▼▼▼ リッチなヘルプ画面ウィジェット ▼▼▼
class _HelpContentSheet extends StatelessWidget {
  final String sectionKey;
  const _HelpContentSheet({required this.sectionKey});

  @override
  Widget build(BuildContext context) {
    // セクションごとのデータ定義
    String title = '';
    String thought = '';
    IconData icon = Icons.help;
    Color color = Colors.grey;
    List<Map<String, String>> items = [];

    switch (sectionKey) {
      case 'type':
        title = 'クエストの種類';
        icon = Icons.category;
        color = Colors.orange;
        thought =
            '『早く行きたければ一人で行け、遠くへ行きたければみんなで行け』という言葉があります。あなたの冒険に最適なスタイルを選んでください。';
        items = [
          {'label': 'ソロ', 'desc': '自分自身と向き合い、マイペースに目標達成を目指します。'},
          {
            'label': 'フレンド',
            'desc': '仲間と協力してクエストに挑みます。お互いの進捗が共有され、励まし合いながら進めます。'
          },
          {
            'label': 'バトル',
            'desc': 'ライバルと競い合います。努力時間や記録回数でランキング化され、競争心がモチベーションになります。'
          },
        ];
        break;
      case 'basic':
        title = '基本設定';
        icon = Icons.flag;
        color = Colors.green;
        thought = '明確な名前をつけることで、目標は現実味を帯びます。あなたにとって響きの良い、かっこいいタイトルをつけてみましょう。';
        items = [
          {'label': 'クエスト名', 'desc': '達成したい目標の名前です。（例：フルマラソン完走、TOEIC 800点取得）'},
          {'label': 'カテゴリ', 'desc': '目標のジャンルを選びます。バランスよく育てるための指針になります。'},
          {'label': 'Life', 'desc': '生活習慣、早起き、家事など'},
          {'label': 'Study', 'desc': '資格勉強、読書、スキル習得など'},
          {'label': 'Physical', 'desc': '筋トレ、ランニング、ダイエットなど'},
          {'label': 'Social', 'desc': '人脈作り、イベント参加、家族サービスなど'},
          {'label': 'Creative', 'desc': '創作活動、プログラミング、DIYなど'},
          {'label': 'Mental', 'desc': '瞑想、日記、メンタルケアなど'},
        ];
        break;
      case 'why':
        title = 'Why (動機)';
        icon = Icons.psychology;
        color = Colors.blue;
        thought =
            '強力な動機は、挫折しそうな時の最強の武器になります。表面的な理由ではなく、心の奥底にある『熱い想い』を書き留めてください。';
        items = [
          {
            'label': '意気込み',
            'desc': 'なぜその目標を達成したいのですか？達成した時、どんな景色が見えますか？苦しい時に立ち返るための言葉を残しましょう。'
          },
        ];
        break;
      case 'habit':
        title = '習慣化の仕組み';
        icon = Icons.build;
        color = Colors.purple;
        thought =
            '気合いや根性に頼らず、『仕組み』で勝つことが継続の鍵です。脳が自然と動いてしまうような、最強の習慣化システムを構築しましょう。';
        items = [
          {
            'label': 'いつ、どこで',
            'desc':
                '「If-Thenプランニング」と呼ばれる強力なテクニックです。「朝起きたら」「電車に乗ったら」など、既存の行動をトリガーに設定します。'
          },
          {
            'label': '最低目標',
            'desc':
                '「2分ルール」です。どんなにやる気がない日でも、「これだけならできる」という極めて低いハードル（靴を履く、本を開く）を設定し、継続を途切れさせないようにします。'
          },
          {
            'label': 'ご褒美',
            'desc': '行動の直後に「快感」を得ることで、脳はその行動を繰り返したくなります。小さなご褒美を用意しましょう。'
          },
        ];
        break;
      case 'duration':
        title = '期間';
        icon = Icons.date_range;
        color = Colors.redAccent;
        thought = '期限は行動の起爆剤です。未来の自分との約束を交わしましょう。';
        items = [
          {
            'label': '開始日・終了日',
            'desc': 'いつから始めて、いつまでに達成するかを決めます。期間が決まっているからこそ、人は集中して力を発揮できます。'
          },
        ];
        break;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85, // 画面の85%の高さ
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ヘッダーハンドル
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // タイトルエリア
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10),

          // スクロールエリア
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // 想いセクション
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.15), Colors.transparent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border(
                      left: BorderSide(color: color, width: 4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DESIGNER\'S THOUGHT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        thought,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 項目リスト
                ...items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 18, color: color),
                            const SizedBox(width: 8),
                            Text(
                              item['label']!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 26.0),
                          child: Text(
                            item['desc']!,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
