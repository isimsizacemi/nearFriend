import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/dm_request_model.dart';
import '../services/match_service.dart';
import '../utils/app_theme.dart';
import 'checkin_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final MatchService _matchService = MatchService();
  late TabController _tabController;

  List<UserModel> _matchedUsers = [];
  List<UserModel> _receivedMatches = [];
  List<DMRequestModel> _dmRequests = [];
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final matchedUsers = await _matchService.getMatchedUsers();
      final receivedMatches = await _matchService.getReceivedMatches();
      final dmRequests = await _loadDMRequests();
      final chats = await _loadChats();

      if (mounted) {
        setState(() {
          _matchedUsers = matchedUsers;
          _receivedMatches = receivedMatches;
          _dmRequests = dmRequests;
          _chats = chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Veriler yüklenirken hata: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadChats() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return [];

      print('Chat\'ler yükleniyor...');
      print('Mevcut kullanıcı UID: ${currentUser.uid}');

      // Basit query kullan - sadece participants array'ini kontrol et
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      print('Bulunan chat sayısı: ${snapshot.docs.length}');

      final allChats = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        print('Chat: ${doc.id} - ${data}');
        return data;
      }).toList();

      // Client-side filtering: sadece aktif chat'leri al
      final activeChats =
          allChats.where((chat) => chat['isActive'] == true).toList();

      // Client-side sorting: lastMessageAt'e göre sırala
      activeChats.sort((a, b) {
        final aTime = a['lastMessageAt'] as Timestamp?;
        final bTime = b['lastMessageAt'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime); // En yeni önce
      });

      print('Yüklenen aktif chat sayısı: ${activeChats.length}');
      return activeChats;
    } catch (e) {
      print('Chat\'ler yüklenirken hata: $e');
      return [];
    }
  }

  Future<List<DMRequestModel>> _loadDMRequests() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return [];

      print('DM istekleri aranıyor...');
      print('Mevcut kullanıcı UID: ${currentUser.uid}');

      final snapshot = await FirebaseFirestore.instance
          .collection('dm_requests')
          .where('toUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      print('Bulunan DM isteği sayısı: ${snapshot.docs.length}');

      final requests = snapshot.docs.map((doc) {
        print('DM isteği: ${doc.id} - ${doc.data()}');
        return DMRequestModel.fromFirestore(doc);
      }).toList();

      print('Yüklenen DM isteği sayısı: ${requests.length}');
      return requests;
    } catch (e) {
      print('DM istekleri yüklenirken hata: $e');
      return [];
    }
  }

  Future<void> _acceptMatch(UserModel user) async {
    try {
      await _matchService.acceptMatch(user.id);
      await _loadData(); // Verileri yenile

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.displayName} ile eşleştin!'),
            backgroundColor: AppTheme.iosGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      print('Eşleşme kabul edilirken hata: $e');
    }
  }

  Future<void> _rejectMatch(UserModel user) async {
    try {
      await _matchService.rejectMatch(user.id);
      await _loadData(); // Verileri yenile

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.displayName} reddedildi'),
            backgroundColor: AppTheme.iosRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      print('Eşleşme reddedilirken hata: $e');
    }
  }

  Future<void> _acceptDMRequest(DMRequestModel request) async {
    try {
      // DM isteğini kabul et
      await FirebaseFirestore.instance
          .collection('dm_requests')
          .doc(request.id)
          .update({'status': 'accepted'});

      // Chat oluştur
      final chatId = [request.fromUserId, request.toUserId]..sort();
      final chatIdString = chatId.join('_');

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatIdString)
          .set({
        'user1Id': request.fromUserId,
        'user2Id': request.toUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'isActive': true,
        'participants': [request.fromUserId, request.toUserId],
      });

      // Eğer "Seni beğendim" tipi DM isteği ise, otomatik mesaj gönder
      if (request.type == 'like') {
        await FirebaseFirestore.instance.collection('messages').add({
          'senderId': request.fromUserId,
          'receiverId': request.toUserId,
          'content': 'Seni beğendim 😊',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'messageType': 'text',
        });

        // Chat'i güncelle
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatIdString)
            .update({
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessage': 'Seni beğendim 😊',
        });
      }

      await _loadData(); // Verileri yenile

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('DM isteği kabul edildi'),
            backgroundColor: AppTheme.iosGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      print('DM isteği kabul edilirken hata: $e');
    }
  }

  Future<void> _rejectDMRequest(DMRequestModel request) async {
    try {
      // DM isteğini reddet
      await FirebaseFirestore.instance
          .collection('dm_requests')
          .doc(request.id)
          .update({'status': 'rejected'});

      await _loadData(); // Verileri yenile

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('DM isteği reddedildi'),
            backgroundColor: AppTheme.iosRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      print('DM isteği reddedilirken hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.iosDarkBackground : AppTheme.iosBackground,
      body: SafeArea(
        child: Column(
          children: [
            // iOS Style Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.iosDarkSecondaryBackground
                    : AppTheme.iosSecondaryBackground,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.iosPurple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chat_bubble,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sohbet',
                          style: AppTheme.iosFontMedium.copyWith(
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                        Text(
                          '${_chats.length} aktif sohbet',
                          style: AppTheme.iosFontSmall.copyWith(
                            color: isDark
                                ? AppTheme.iosDarkSecondaryText
                                : AppTheme.iosSecondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadData,
                    icon: Icon(
                      Icons.refresh,
                      color: AppTheme.iosPurple,
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.iosDarkTertiaryBackground
                    : AppTheme.iosTertiaryBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.iosPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: isDark
                    ? AppTheme.iosDarkSecondaryText
                    : AppTheme.iosSecondaryText,
                labelStyle: AppTheme.iosFontBold,
                unselectedLabelStyle: AppTheme.iosFont,
                tabs: [
                  Tab(text: 'DM\'ler'),
                  Tab(
                    text:
                        'İstekler${_dmRequests.isNotEmpty ? ' (${_dmRequests.length})' : ''}',
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.iosDarkSecondaryBackground
                              : AppTheme.iosSecondaryBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: AppTheme.iosPurple,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Sohbetler yükleniyor...',
                              style: AppTheme.iosFont.copyWith(
                                color: isDark
                                    ? AppTheme.iosDarkSecondaryText
                                    : AppTheme.iosSecondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDMsTab(),
                        _buildRequestsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDMsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_chats.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.iosDarkSecondaryBackground
                : AppTheme.iosSecondaryBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: isDark
                    ? AppTheme.iosDarkSecondaryText
                    : AppTheme.iosSecondaryText,
              ),
              const SizedBox(height: 16),
              Text(
                'Henüz chat yok',
                style: AppTheme.iosFontMedium.copyWith(
                  color: isDark
                      ? AppTheme.iosDarkPrimaryText
                      : AppTheme.iosPrimaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'DM isteklerini kabul et veya eşleşme yap!',
                style: AppTheme.iosFontSmall.copyWith(
                  color: isDark
                      ? AppTheme.iosDarkSecondaryText
                      : AppTheme.iosSecondaryText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.iosPurple,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return _buildChatTileFromData(chat);
        },
      ),
    );
  }

  Widget _buildRequestsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.iosPurple,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Eşleşme istekleri
          if (_receivedMatches.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.iosPink.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Eşleşme İstekleri',
                style: AppTheme.iosFontMedium.copyWith(
                  color: AppTheme.iosPink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._receivedMatches.map((user) => _buildRequestTile(user)),
            const SizedBox(height: 20),
          ],

          // DM istekleri
          if (_dmRequests.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.iosBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'DM İstekleri',
                style: AppTheme.iosFontMedium.copyWith(
                  color: AppTheme.iosBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._dmRequests.map((request) => _buildDMRequestTile(request)),
          ],

          // Boş durum
          if (_receivedMatches.isEmpty && _dmRequests.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.iosDarkSecondaryBackground
                      : AppTheme.iosSecondaryBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_outlined,
                      size: 64,
                      color: isDark
                          ? AppTheme.iosDarkSecondaryText
                          : AppTheme.iosSecondaryText,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gelen istek yok',
                      style: AppTheme.iosFontMedium.copyWith(
                        color: isDark
                            ? AppTheme.iosDarkPrimaryText
                            : AppTheme.iosPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Seni beğenen kişiler burada görünecek',
                      style: AppTheme.iosFontSmall.copyWith(
                        color: isDark
                            ? AppTheme.iosDarkSecondaryText
                            : AppTheme.iosSecondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatTile(UserModel user, {required bool isMatched}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            user.photoURL != null ? NetworkImage(user.photoURL!) : null,
        child: user.photoURL == null ? const Icon(Icons.person) : null,
      ),
      title: Text(user.displayName),
      subtitle: Text('${user.university} - ${user.department}'),
      trailing: isMatched
          ? IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatDetailScreen(
                      otherUserId: user.id,
                      otherUserName: user.displayName,
                      otherUserPhoto: user.photoURL,
                    ),
                  ),
                );
              },
            )
          : null,
      onTap: isMatched
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatDetailScreen(
                    otherUserId: user.id,
                    otherUserName: user.displayName,
                    otherUserPhoto: user.photoURL,
                  ),
                ),
              );
            }
          : null,
    );
  }

  Widget _buildRequestTile(UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.iosDarkSecondaryBackground
            : AppTheme.iosSecondaryBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppTheme.iosPink.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: user.photoURL != null
                        ? Image.network(
                            user.photoURL!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: isDark
                                    ? AppTheme.iosDarkTertiaryBackground
                                    : AppTheme.iosTertiaryBackground,
                                child: Icon(
                                  Icons.person,
                                  size: 30,
                                  color: isDark
                                      ? AppTheme.iosDarkSecondaryText
                                      : AppTheme.iosSecondaryText,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: isDark
                                ? AppTheme.iosDarkTertiaryBackground
                                : AppTheme.iosTertiaryBackground,
                            child: Icon(
                              Icons.person,
                              size: 30,
                              color: isDark
                                  ? AppTheme.iosDarkSecondaryText
                                  : AppTheme.iosSecondaryText,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: AppTheme.iosFontMedium.copyWith(
                          color: isDark
                              ? AppTheme.iosDarkPrimaryText
                              : AppTheme.iosPrimaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user.age} yaşında',
                        style: AppTheme.iosFontSmall.copyWith(
                          color: isDark
                              ? AppTheme.iosDarkSecondaryText
                              : AppTheme.iosSecondaryText,
                        ),
                      ),
                      Text(
                        '${user.university} - ${user.department}',
                        style: AppTheme.iosFontSmall.copyWith(
                          color: isDark
                              ? AppTheme.iosDarkSecondaryText
                              : AppTheme.iosSecondaryText,
                        ),
                      ),
                      if (user.bio != null && user.bio!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.iosDarkTertiaryBackground
                                : AppTheme.iosTertiaryBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            user.bio!,
                            style: AppTheme.iosFontSmall.copyWith(
                              color: isDark
                                  ? AppTheme.iosDarkSecondaryText
                                  : AppTheme.iosSecondaryText,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptMatch(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.iosGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Kabul Et',
                          style: AppTheme.iosFontMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _rejectMatch(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.iosRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Reddet',
                          style: AppTheme.iosFontMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDMRequestTile(DMRequestModel request) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(request.fromUserId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.iosDarkSecondaryBackground
                  : AppTheme.iosSecondaryBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.iosDarkTertiaryBackground
                        : AppTheme.iosTertiaryBackground,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    Icons.person,
                    color: isDark
                        ? AppTheme.iosDarkSecondaryText
                        : AppTheme.iosSecondaryText,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.iosDarkTertiaryBackground
                              : AppTheme.iosTertiaryBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 150,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.iosDarkTertiaryBackground
                              : AppTheme.iosTertiaryBackground,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox.shrink();

        final displayName = userData['displayName'] ?? 'Kullanıcı';
        final photoURL = userData['photoURL'];
        final university = userData['university'] ?? '';
        final department = userData['department'] ?? '';

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.iosDarkSecondaryBackground
                : AppTheme.iosSecondaryBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: AppTheme.iosBlue.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: photoURL != null
                            ? Image.network(
                                photoURL,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: isDark
                                        ? AppTheme.iosDarkTertiaryBackground
                                        : AppTheme.iosTertiaryBackground,
                                    child: Icon(
                                      Icons.person,
                                      color: isDark
                                          ? AppTheme.iosDarkSecondaryText
                                          : AppTheme.iosSecondaryText,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: isDark
                                    ? AppTheme.iosDarkTertiaryBackground
                                    : AppTheme.iosTertiaryBackground,
                                child: Icon(
                                  Icons.person,
                                  color: isDark
                                      ? AppTheme.iosDarkSecondaryText
                                      : AppTheme.iosSecondaryText,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: AppTheme.iosFontMedium.copyWith(
                              color: isDark
                                  ? AppTheme.iosDarkPrimaryText
                                  : AppTheme.iosPrimaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$university - $department',
                            style: AppTheme.iosFontSmall.copyWith(
                              color: isDark
                                  ? AppTheme.iosDarkSecondaryText
                                  : AppTheme.iosSecondaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.iosBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              request.message,
                              style: AppTheme.iosFontSmall.copyWith(
                                color: AppTheme.iosBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptDMRequest(request),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.iosGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Kabul Et',
                              style: AppTheme.iosFontMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _rejectDMRequest(request),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.iosRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Reddet',
                              style: AppTheme.iosFontMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatTileFromData(Map<String, dynamic> chat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;
    final otherUserId =
        chat['user1Id'] == currentUser?.uid ? chat['user2Id'] : chat['user1Id'];

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.iosDarkSecondaryBackground
                  : AppTheme.iosSecondaryBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.iosDarkTertiaryBackground
                        : AppTheme.iosTertiaryBackground,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    Icons.person,
                    color: isDark
                        ? AppTheme.iosDarkSecondaryText
                        : AppTheme.iosSecondaryText,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.iosDarkTertiaryBackground
                              : AppTheme.iosTertiaryBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 150,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.iosDarkTertiaryBackground
                              : AppTheme.iosTertiaryBackground,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox.shrink();

        final displayName = userData['displayName'] ?? 'Kullanıcı';
        final photoURL = userData['photoURL'];
        final lastMessage = chat['lastMessage'] ?? '';
        final lastMessageAt = chat['lastMessageAt'] as Timestamp?;

        // UserModel oluştur
        final otherUser = UserModel(
          id: otherUserId,
          displayName: displayName,
          email: userData['email'] ?? '',
          photoURL: photoURL,
          university: userData['university'] ?? '',
          department: userData['department'] ?? '',
          age: userData['age'] ?? 0,
          gender: userData['gender'] ?? '',
          bio: userData['bio'],
          interests: List<String>.from(userData['interests'] ?? []),
          createdAt:
              (userData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastActiveAt: (userData['lastActiveAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          isOnline: userData['isOnline'] ?? false,
          currentLocation: userData['currentLocation'] != null
              ? GeoPoint(
                  (userData['currentLocation'] as GeoPoint).latitude,
                  (userData['currentLocation'] as GeoPoint).longitude,
                )
              : null,
          blockedUsers: List<String>.from(userData['blockedUsers'] ?? []),
          matchedUsers: List<String>.from(userData['matchedUsers'] ?? []),
          pendingMatches: List<String>.from(userData['pendingMatches'] ?? []),
          receivedMatches: List<String>.from(userData['receivedMatches'] ?? []),
        );

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.iosDarkSecondaryBackground
                : AppTheme.iosSecondaryBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: AppTheme.iosPurple.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: photoURL != null
                    ? Image.network(
                        photoURL,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: isDark
                                ? AppTheme.iosDarkTertiaryBackground
                                : AppTheme.iosTertiaryBackground,
                            child: Icon(
                              Icons.person,
                              color: isDark
                                  ? AppTheme.iosDarkSecondaryText
                                  : AppTheme.iosSecondaryText,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: isDark
                            ? AppTheme.iosDarkTertiaryBackground
                            : AppTheme.iosTertiaryBackground,
                        child: Icon(
                          Icons.person,
                          color: isDark
                              ? AppTheme.iosDarkSecondaryText
                              : AppTheme.iosSecondaryText,
                        ),
                      ),
              ),
            ),
            title: Text(
              displayName,
              style: AppTheme.iosFontMedium.copyWith(
                color: isDark
                    ? AppTheme.iosDarkPrimaryText
                    : AppTheme.iosPrimaryText,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lastMessage.isNotEmpty)
                  Text(
                    lastMessage,
                    style: AppTheme.iosFontSmall.copyWith(
                      color: isDark
                          ? AppTheme.iosDarkSecondaryText
                          : AppTheme.iosSecondaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (lastMessageAt != null)
                  Text(
                    _formatTimeAgo(lastMessageAt.toDate()),
                    style: AppTheme.iosFontCaption.copyWith(
                      color: isDark
                          ? AppTheme.iosDarkSecondaryText
                          : AppTheme.iosSecondaryText,
                    ),
                  ),
              ],
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDark
                  ? AppTheme.iosDarkSecondaryText
                  : AppTheme.iosSecondaryText,
            ),
            onTap: () {
              // Chat detail screen'e git
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatDetailScreen(
                    otherUserId: otherUserId,
                    otherUserName: displayName,
                    otherUserPhoto: photoURL,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else {
      return '${difference.inDays} gün önce';
    }
  }
}

// Chat Detail Screen - Real Implementation
class ChatDetailScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;

  const ChatDetailScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _chatId;

  @override
  void initState() {
    super.initState();
    _loadChat();
  }

  Future<void> _loadChat() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Chat ID'sini oluştur (sıralı olması için)
      final users = [currentUser.uid, widget.otherUserId]..sort();
      _chatId = '${users[0]}_${users[1]}';

      // Mevcut mesajları yükle - messages koleksiyonundan
      final messagesQuery = await FirebaseFirestore.instance
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      // Mesajları filtrele
      final filteredMessages = messagesQuery.docs
          .map((doc) => doc.data())
          .where((message) =>
              (message['senderId'] == currentUser.uid &&
                  message['receiverId'] == widget.otherUserId) ||
              (message['senderId'] == widget.otherUserId &&
                  message['receiverId'] == currentUser.uid))
          .toList();

      setState(() {
        _messages = filteredMessages;
        _isLoading = false;
      });

      // Real-time mesaj dinleyicisi
      FirebaseFirestore.instance
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .listen((snapshot) {
        final filteredMessages = snapshot.docs
            .map((doc) => doc.data())
            .where((message) =>
                (message['senderId'] == currentUser.uid &&
                    message['receiverId'] == widget.otherUserId) ||
                (message['senderId'] == widget.otherUserId &&
                    message['receiverId'] == currentUser.uid))
            .toList();

        setState(() {
          _messages = filteredMessages;
        });
        _scrollToBottom();
      });
    } catch (e) {
      print('Chat yüklenirken hata: $e');
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Chat dokümanını oluştur/güncelle
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
        'user1Id': currentUser.uid,
        'user2Id': widget.otherUserId,
        'lastMessage': message,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'participants': [currentUser.uid, widget.otherUserId],
      }, SetOptions(merge: true));

      // Mesajı messages koleksiyonuna ekle
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': currentUser.uid,
        'receiverId': widget.otherUserId,
        'content': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'messageType': 'text',
      });

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print('Mesaj gönderilirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesaj gönderilemedi: $e'),
          backgroundColor: AppTheme.iosRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.iosDarkBackground : AppTheme.iosBackground,
      appBar: AppBar(
        backgroundColor: isDark
            ? AppTheme.iosDarkSecondaryBackground
            : AppTheme.iosSecondaryBackground,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.iosPurple.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: widget.otherUserPhoto != null
                    ? Image.network(
                        widget.otherUserPhoto!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: isDark
                                ? AppTheme.iosDarkTertiaryBackground
                                : AppTheme.iosTertiaryBackground,
                            child: Icon(
                              Icons.person,
                              color: isDark
                                  ? AppTheme.iosDarkSecondaryText
                                  : AppTheme.iosSecondaryText,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: isDark
                            ? AppTheme.iosDarkTertiaryBackground
                            : AppTheme.iosTertiaryBackground,
                        child: Icon(
                          Icons.person,
                          color: isDark
                              ? AppTheme.iosDarkSecondaryText
                              : AppTheme.iosSecondaryText,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.otherUserName,
              style: AppTheme.iosFontMedium.copyWith(
                color: isDark
                    ? AppTheme.iosDarkPrimaryText
                    : AppTheme.iosPrimaryText,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDark
                ? AppTheme.iosDarkSecondaryText
                : AppTheme.iosSecondaryText,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.iosPurple,
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          margin: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.iosDarkSecondaryBackground
                                : AppTheme.iosSecondaryBackground,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: isDark
                                    ? AppTheme.iosDarkSecondaryText
                                    : AppTheme.iosSecondaryText,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Henüz mesaj yok',
                                style: AppTheme.iosFontMedium.copyWith(
                                  color: isDark
                                      ? AppTheme.iosDarkPrimaryText
                                      : AppTheme.iosPrimaryText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'İlk mesajını gönder!',
                                style: AppTheme.iosFontSmall.copyWith(
                                  color: isDark
                                      ? AppTheme.iosDarkSecondaryText
                                      : AppTheme.iosSecondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message['senderId'] == currentUser?.uid;

                          return _buildMessageBubble(message, isMe, isDark);
                        },
                      ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.iosDarkSecondaryBackground
                  : AppTheme.iosSecondaryBackground,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.iosDarkTertiaryBackground
                            : AppTheme.iosTertiaryBackground,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Mesaj yaz...',
                          hintStyle: AppTheme.iosFont.copyWith(
                            color: isDark
                                ? AppTheme.iosDarkSecondaryText
                                : AppTheme.iosSecondaryText,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        style: AppTheme.iosFont.copyWith(
                          color: isDark
                              ? AppTheme.iosDarkPrimaryText
                              : AppTheme.iosPrimaryText,
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.iosPurple,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      Map<String, dynamic> message, bool isMe, bool isDark) {
    final content = message['content'] ?? '';
    final timestamp = message['timestamp'] as Timestamp?;
    final currentUser = FirebaseAuth.instance.currentUser;

    // Check-in mesajı kontrolü
    final isCheckinMessage = content.contains('check-in') ||
        content.contains('Check-in') ||
        content.contains('checkin') ||
        content.contains('Checkin');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.iosPurple.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: widget.otherUserPhoto != null
                    ? Image.network(
                        widget.otherUserPhoto!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: isDark
                                ? AppTheme.iosDarkTertiaryBackground
                                : AppTheme.iosTertiaryBackground,
                            child: Icon(
                              Icons.person,
                              size: 16,
                              color: isDark
                                  ? AppTheme.iosDarkSecondaryText
                                  : AppTheme.iosSecondaryText,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: isDark
                            ? AppTheme.iosDarkTertiaryBackground
                            : AppTheme.iosTertiaryBackground,
                        child: Icon(
                          Icons.person,
                          size: 16,
                          color: isDark
                              ? AppTheme.iosDarkSecondaryText
                              : AppTheme.iosSecondaryText,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onTap: isCheckinMessage
                  ? () {
                      // Debug bilgisi
                      print('Check-in mesajı tıklandı');
                      print('Mesaj içeriği: $content');
                      print('Check-in ID: ${message['checkinId']}');
                      print('Check-in Data: ${message['checkinData']}');

                      // Check-in ID'si varsa kullan, yoksa check-in verilerini kullan
                      final checkinId = message['checkinId'] ?? '';
                      final checkinData =
                          message['checkinData'] as Map<String, dynamic>?;

                      if (checkinId.isNotEmpty) {
                        // Check-in ID'si var, normal şekilde git
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CheckinDetailScreen(
                              checkinId: checkinId,
                            ),
                          ),
                        );
                      } else if (checkinData != null) {
                        // Check-in verileri var, bunları kullan
                        print('Check-in verileri kullanılıyor: $checkinData');
                        // Burada check-in verilerini kullanarak detay sayfası açabiliriz
                        // Şimdilik sadece ID'yi kullanıyoruz
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CheckinDetailScreen(
                              checkinId: checkinData['id'] ?? '',
                            ),
                          ),
                        );
                      } else {
                        // Hiçbir veri yok, hata mesajı göster
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                const Text('Check-in bilgileri bulunamadı'),
                            backgroundColor: AppTheme.iosRed,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    }
                  : null,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppTheme.iosPurple
                      : isDark
                          ? AppTheme.iosDarkTertiaryBackground
                          : AppTheme.iosTertiaryBackground,
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomLeft: isMe
                        ? const Radius.circular(20)
                        : const Radius.circular(4),
                    bottomRight: isMe
                        ? const Radius.circular(4)
                        : const Radius.circular(20),
                  ),
                  border: isCheckinMessage
                      ? Border.all(
                          color: AppTheme.iosBlue.withOpacity(0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            content,
                            style: AppTheme.iosFont.copyWith(
                              color: isMe
                                  ? Colors.white
                                  : isDark
                                      ? AppTheme.iosDarkPrimaryText
                                      : AppTheme.iosPrimaryText,
                            ),
                          ),
                        ),
                        if (isCheckinMessage) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: isMe
                                ? Colors.white.withOpacity(0.7)
                                : AppTheme.iosBlue,
                          ),
                        ],
                      ],
                    ),
                    if (timestamp != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(timestamp.toDate()),
                        style: AppTheme.iosFontCaption.copyWith(
                          color: isMe
                              ? Colors.white.withOpacity(0.7)
                              : isDark
                                  ? AppTheme.iosDarkSecondaryText
                                  : AppTheme.iosSecondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.iosPurple.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: currentUser?.photoURL != null
                    ? Image.network(
                        currentUser!.photoURL!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: isDark
                                ? AppTheme.iosDarkTertiaryBackground
                                : AppTheme.iosTertiaryBackground,
                            child: Icon(
                              Icons.person,
                              size: 16,
                              color: isDark
                                  ? AppTheme.iosDarkSecondaryText
                                  : AppTheme.iosSecondaryText,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: isDark
                            ? AppTheme.iosDarkTertiaryBackground
                            : AppTheme.iosTertiaryBackground,
                        child: Icon(
                          Icons.person,
                          size: 16,
                          color: isDark
                              ? AppTheme.iosDarkSecondaryText
                              : AppTheme.iosSecondaryText,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dk';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} sa';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}
