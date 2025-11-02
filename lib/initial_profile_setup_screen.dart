// lib/initial_profile_setup_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:flutter/services.dart'; // ◀◀◀ 削除

class InitialProfileSetupScreen extends StatefulWidget {
  const InitialProfileSetupScreen({super.key});

  @override
  State<InitialProfileSetupScreen> createState() =>
      _InitialProfileSetupScreenState();
}

class _InitialProfileSetupScreenState extends State<InitialProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  // late TextEditingController _bioController; // ◀◀◀ 削除

  File? _imageFile;
  String? _currentPhotoURL;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    // _bioController = TextEditingController(); // ◀◀◀ 削除
    _currentPhotoURL = user?.photoURL;
  }

  @override
  void dispose() {
    _nameController.dispose();
    // _bioController.dispose(); // ◀◀◀ 削除
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _currentPhotoURL = null;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      String newName = _nameController.text.trim();
      // String newBio = _bioController.text.trim(); // ◀◀◀ 削除
      String? newPhotoURL = _currentPhotoURL;

      if (_imageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures/${user.uid}');
        await storageRef.putFile(_imageFile!);
        newPhotoURL = await storageRef.getDownloadURL();
      }

      await user.updateDisplayName(newName);
      if (newPhotoURL != null) {
        await user.updatePhotoURL(newPhotoURL);
      }

      // ▼▼▼ bio にデフォルト値を設定して保存 ▼▼▼
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'displayName': newName,
        'bio': 'よろしくお願いします！', // ◀◀◀ 自己紹介を自動設定
        'photoURL': newPhotoURL,
      });
      // ▲▲▲
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('プロフィールの保存に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィールを設定'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- プロフィール画像設定 ---
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (_currentPhotoURL != null
                              ? NetworkImage(_currentPhotoURL!)
                              : null) as ImageProvider?,
                      child: (_imageFile == null && _currentPhotoURL == null)
                          ? Icon(Icons.person,
                              size: 60, color: Colors.grey[600])
                          : null,
                    ),
                    Material(
                      color: Theme.of(context).colorScheme.primary,
                      shape: const CircleBorder(
                        side: BorderSide(color: Colors.black, width: 2),
                      ),
                      child: InkWell(
                        onTap: _pickImage,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.camera_alt,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // --- 名前設定 ---
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名前'),
                // inputFormatters: [ ... ], // ◀◀◀ 英数字制限を削除
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '名前は必須です';
                  }
                  if (value.length > 20) {
                    return '名前は20文字以内にしてください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // --- 自己紹介設定 (削除) ---
              // TextFormField( ... ), // ◀◀◀ 削除
              // const SizedBox(height: 32),

              // --- 保存ボタン ---
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.start),
                      label: const Text('冒険を始める'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
