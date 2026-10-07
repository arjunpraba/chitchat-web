import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const StrangerChatApp());
}

// ============================================================
// APP
// ============================================================

class StrangerChatApp extends StatelessWidget {
  const StrangerChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChitChat',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const StrangerChatScreen(),
    );
  }
}

// ============================================================
// MESSAGE STATUS
// ============================================================

enum MessageStatus {
  sending,
  sent,
  delivered,
}

// ============================================================
// CHAT MESSAGE
// ============================================================

class ChatMessage {
  String id;
  final String text;
  final bool isMine;
  final DateTime timestamp;

  String? replyToId;
  String? replyToText;

  MessageStatus status;

  final Map<String, int> reactions;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMine,
    required this.timestamp,
    this.replyToId,
    this.replyToText,
    this.status = MessageStatus.sending,
    Map<String, int>? reactions,
  }) : reactions = reactions ?? {};
}

// ============================================================
// CHAT THEME
// ============================================================

class ChatTheme {
  final String name;
  final Color primary;
  final Color myMessage;
  final Color strangerMessage;
  final Color background;

  const ChatTheme({
    required this.name,
    required this.primary,
    required this.myMessage,
    required this.strangerMessage,
    required this.background,
  });
}

const List<ChatTheme> chatThemes = [
  ChatTheme(
    name: 'Purple',
    primary: Colors.deepPurple,
    myMessage: Colors.deepPurple,
    strangerMessage: Color(0xFF303030),
    background: Color(0xFF121212),
  ),
  ChatTheme(
    name: 'Blue',
    primary: Colors.blue,
    myMessage: Colors.blue,
    strangerMessage: Color(0xFF263238),
    background: Color(0xFF0D1117),
  ),
  ChatTheme(
    name: 'Green',
    primary: Colors.green,
    myMessage: Colors.green,
    strangerMessage: Color(0xFF26332A),
    background: Color(0xFF101510),
  ),
  ChatTheme(
    name: 'Pink',
    primary: Colors.pink,
    myMessage: Colors.pink,
    strangerMessage: Color(0xFF33252B),
    background: Color(0xFF160F13),
  ),
  ChatTheme(
    name: 'Orange',
    primary: Colors.orange,
    myMessage: Colors.deepOrange,
    strangerMessage: Color(0xFF332A24),
    background: Color(0xFF15110D),
  ),
  ChatTheme(
    name: 'Dark',
    primary: Colors.grey,
    myMessage: Color(0xFF424242),
    strangerMessage: Color(0xFF222222),
    background: Color(0xFF080808),
  ),
  ChatTheme(
    name: 'Cyan',
    primary: Colors.cyan,
    myMessage: Color(0xFF00838F),
    strangerMessage: Color(0xFF263238),
    background: Color(0xFF071417),
  ),
  ChatTheme(
    name: 'Red',
    primary: Colors.redAccent,
    myMessage: Color(0xFFC62828),
    strangerMessage: Color(0xFF332323),
    background: Color(0xFF160B0B),
  ),
  ChatTheme(
    name: 'Indigo',
    primary: Colors.indigoAccent,
    myMessage: Color(0xFF3949AB),
    strangerMessage: Color(0xFF252A40),
    background: Color(0xFF0C0E18),
  ),
];

// ============================================================
// CHAT BACKGROUND
// ============================================================

enum ChatBackground {
  solid,
  gradient,
  midnight,
  galaxy,
  ocean,
  sunset,
  hearts,
  bubbles,
}

String backgroundName(ChatBackground background) {
  switch (background) {
    case ChatBackground.solid:
      return 'Solid';
    case ChatBackground.gradient:
      return 'Gradient';
    case ChatBackground.midnight:
      return 'Midnight';
    case ChatBackground.galaxy:
      return 'Galaxy';
    case ChatBackground.ocean:
      return 'Ocean';
    case ChatBackground.sunset:
      return 'Sunset';
    case ChatBackground.hearts:
      return 'Hearts';
    case ChatBackground.bubbles:
      return 'Bubbles';
  }
}

// ============================================================
// CHAT SCREEN
// ============================================================

class StrangerChatScreen extends StatefulWidget {
  const StrangerChatScreen({super.key});

  @override
  State<StrangerChatScreen> createState() =>
      _StrangerChatScreenState();
}

class _StrangerChatScreenState extends State<StrangerChatScreen>
    with TickerProviderStateMixin {

  static const String serverUrl =
      'wss://chit-chat-k4oy.onrender.com';

  WebSocketChannel? channel;

  StreamSubscription? socketSubscription;

  final TextEditingController messageController =
  TextEditingController();

  final ScrollController scrollController =
  ScrollController();

  final List<ChatMessage> messages = [];

  bool isConnected = false;
  bool isSearching = false;
  bool isMatched = false;

  bool strangerTyping = false;

  bool isReconnecting = false;

  bool partnerLeft = false;

  int activeUsers = 0;

  String status = 'Connecting...';

  String? myUserId;
  String? partnerId;

  ChatTheme selectedTheme = chatThemes[0];

  ChatBackground selectedBackground =
      ChatBackground.solid;

  Timer? typingTimer;

  Timer? reconnectTimer;

  bool isTyping = false;

  int reconnectAttempt = 0;

  bool manuallyStopped = false;

  ChatMessage? replyingTo;

  late AnimationController matchAnimationController;

  late Animation<double> matchScaleAnimation;

  bool showNewMatchAnimation = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    matchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 700,
      ),
    );

    matchScaleAnimation = CurvedAnimation(
      parent: matchAnimationController,
      curve: Curves.elasticOut,
    );

    connectToServer();
  }

  // ============================================================
  // CONNECT
  // ============================================================

  void connectToServer({
    bool autoReconnect = false,
  }) {
    if (manuallyStopped) {
      return;
    }

    try {
      setState(() {
        isReconnecting = autoReconnect;

        if (autoReconnect) {
          status = 'Reconnecting...';
        }
      });

      channel = WebSocketChannel.connect(
        Uri.parse(serverUrl),
      );

      socketSubscription =
          channel!.stream.listen(
            handleServerMessage,
            onError: (error) {
              handleConnectionLost();
            },
            onDone: () {
              handleConnectionLost();
            },
            cancelOnError: true,
          );

      reconnectAttempt = 0;

    } catch (e) {
      handleConnectionLost();
    }
  }

  // ============================================================
  // CONNECTION LOST
  // ============================================================

  void handleConnectionLost() {
    if (!mounted || manuallyStopped) {
      return;
    }

    if (isConnected) {
      setState(() {
        isConnected = false;
        isReconnecting = true;
        strangerTyping = false;
        status = 'Connection lost';
      });
    }

    scheduleReconnect();
  }

  // ============================================================
  // RECONNECT
  // ============================================================

  void scheduleReconnect() {
    if (manuallyStopped) {
      return;
    }

    reconnectTimer?.cancel();

    reconnectAttempt++;

    final seconds =
    reconnectAttempt.clamp(1, 10);

    reconnectTimer = Timer(
      Duration(seconds: seconds),
          () {
        if (!mounted || manuallyStopped) {
          return;
        }

        connectToServer(
          autoReconnect: true,
        );
      },
    );
  }

  // ============================================================
  // SERVER MESSAGE
  // ============================================================

  void handleServerMessage(dynamic data) {
    try {
      final Map<String, dynamic> json =
      jsonDecode(data.toString());

      final String type =
          json['type']?.toString() ?? '';

      switch (type) {

      // ------------------------------------------------------
      // CONNECTED
      // ------------------------------------------------------

        case 'connected':
          setState(() {
            isConnected = true;
            isReconnecting = false;
            status = 'Online';

            myUserId =
                json['userId']?.toString();

            reconnectAttempt = 0;
          });

          // If we were searching when the connection died,
          // automatically search again.
          if (isSearching && !isMatched) {
            Future.delayed(
              const Duration(milliseconds: 300),
                  () {
                sendToServer({
                  'type': 'start',
                });
              },
            );
          }

          break;

      // ------------------------------------------------------
      // ACTIVE USERS
      // ------------------------------------------------------

        case 'active_users':
          final int count =
              int.tryParse(
                json['count']?.toString() ??
                    '0',
              ) ??
                  0;

          if (!mounted) return;

          setState(() {
            activeUsers = count;
          });

          break;

      // ------------------------------------------------------
      // WAITING
      // ------------------------------------------------------

        case 'waiting':
          if (!mounted) return;

          setState(() {
            isSearching = true;
            isMatched = false;
            partnerLeft = false;
            strangerTyping = false;
            status = 'Finding a stranger...';
          });

          break;

      // ------------------------------------------------------
      // MATCHED
      // ------------------------------------------------------

        case 'matched':
          handleMatched(json);
          break;

      // ------------------------------------------------------
      // MESSAGE
      // ------------------------------------------------------

        case 'message':
          handleIncomingMessage(json);
          break;

      // ------------------------------------------------------
      // MESSAGE SENT
      // ------------------------------------------------------

        case 'message_sent':
          handleMessageSent(json);
          break;

      // ------------------------------------------------------
      // MESSAGE DELIVERED
      // ------------------------------------------------------

        case 'message_delivered':
          handleMessageDelivered(json);
          break;

      // ------------------------------------------------------
      // REACTION
      // ------------------------------------------------------

        case 'reaction':
          handleReaction(json);
          break;

      // ------------------------------------------------------
      // TYPING
      // ------------------------------------------------------

        case 'typing':
          if (!mounted) return;

          setState(() {
            strangerTyping =
                json['typing'] == true;
          });

          break;

      // ------------------------------------------------------
      // PARTNER LEFT
      // ------------------------------------------------------

        case 'partner_left':
          handlePartnerLeft();
          break;

      // ------------------------------------------------------
      // REPORT
      // ------------------------------------------------------

        case 'report_submitted':
          showMessage(
            'Report submitted. Thank you.',
          );
          break;

      // ------------------------------------------------------
      // BLOCK
      // ------------------------------------------------------

        case 'blocked':
          showMessage(
            'User blocked.',
          );
          break;

      // ------------------------------------------------------
      // STOPPED
      // ------------------------------------------------------

        case 'stopped':
          if (!mounted) return;

          setState(() {
            isSearching = false;
            isMatched = false;
            partnerLeft = false;
            strangerTyping = false;
            status = 'Stopped';
          });

          break;

      // ------------------------------------------------------
      // ERROR
      // ------------------------------------------------------

        case 'error':
          showMessage(
            json['message']?.toString() ??
                'Something went wrong.',
          );

          break;
      }
    } catch (e) {
      debugPrint(
        'Invalid server message: $e',
      );
    }
  }

  // ============================================================
  // MATCHED
  // ============================================================

  void handleMatched(
      Map<String, dynamic> json,
      ) {
    partnerId =
        json['partnerId']?.toString();

    setState(() {
      isSearching = false;
      isMatched = true;
      partnerLeft = false;
      strangerTyping = false;
      status = 'Connected to stranger';

      messages.clear();
      replyingTo = null;
      messageController.clear();
    });

    playMatchAnimation();

    scrollToBottom();
  }

  // ============================================================
  // NEW MATCH ANIMATION
  // ============================================================

  Future<void> playMatchAnimation() async {
    if (!mounted) return;

    setState(() {
      showNewMatchAnimation = true;
    });

    matchAnimationController.reset();

    await matchAnimationController.forward();

    await Future.delayed(
      const Duration(milliseconds: 1100),
    );

    if (!mounted) return;

    setState(() {
      showNewMatchAnimation = false;
    });
  }

  // ============================================================
  // INCOMING MESSAGE
  // ============================================================

  void handleIncomingMessage(
      Map<String, dynamic> json,
      ) {
    final String text =
        json['text']?.toString() ?? '';

    final String messageId =
        json['messageId']?.toString() ??
            DateTime.now()
                .millisecondsSinceEpoch
                .toString();

    if (text.isEmpty) {
      return;
    }

    final int timestamp =
        int.tryParse(
          json['timestamp']
              ?.toString() ??
              '',
        ) ??
            DateTime.now()
                .millisecondsSinceEpoch;

    final String? replyToId =
    json['replyTo']?.toString();

    ChatMessage? replyMessage;

    if (replyToId != null) {
      try {
        replyMessage =
            messages.firstWhere(
                  (message) =>
              message.id == replyToId,
            );
      } catch (_) {}
    }

    final message = ChatMessage(
      id: messageId,
      text: text,
      isMine: false,
      timestamp:
      DateTime.fromMillisecondsSinceEpoch(
        timestamp,
      ),
      replyToId: replyToId,
      replyToText: replyMessage?.text,
      status: MessageStatus.delivered,
    );

    setState(() {
      strangerTyping = false;
      messages.add(message);
    });

    // Tell server that the message reached us.
    sendToServer({
      'type': 'delivered',
      'messageId': messageId,
    });

    scrollToBottom();
  }

  // ============================================================
  // MESSAGE SENT
  // ============================================================

  void handleMessageSent(
      Map<String, dynamic> json,
      ) {
    final String serverMessageId =
        json['messageId']?.toString() ?? '';

    final String clientMessageId =
        json['clientMessageId']?.toString() ?? '';

    if (serverMessageId.isEmpty ||
        clientMessageId.isEmpty) {
      return;
    }

    for (final message in messages) {
      if (message.id == clientMessageId) {
        setState(() {
          // Replace local ID with server ID.
          message.id = serverMessageId;

          // Message has reached the server.
          message.status = MessageStatus.sent;
        });

        break;
      }
    }
  }

  // ============================================================
  // DELIVERED
  // ============================================================

  void handleMessageDelivered(
      Map<String, dynamic> json,
      ) {
    final String messageId =
        json['messageId']?.toString() ??
            '';

    for (final message in messages) {
      if (message.id == messageId) {
        setState(() {
          message.status =
              MessageStatus.delivered;
        });

        break;
      }
    }
  }

  // ============================================================
  // REACTION
  // ============================================================

  void handleReaction(
      Map<String, dynamic> json,
      ) {
    final String messageId =
        json['messageId']?.toString() ??
            '';

    final String emoji =
        json['emoji']?.toString() ??
            '';

    if (emoji.isEmpty) {
      return;
    }

    for (final message in messages) {
      if (message.id == messageId) {
        setState(() {
          message.reactions[emoji] =
              (message.reactions[emoji] ?? 0) +
                  1;
        });

        break;
      }
    }
  }

  // ============================================================
  // PARTNER LEFT
  // ============================================================

  void handlePartnerLeft() {
    if (!mounted) return;

    setState(() {
      isMatched = false;
      isSearching = false;
      strangerTyping = false;
      partnerLeft = true;
      status = 'Stranger left the conversation.';
      replyingTo = null;
    });

    showPartnerLeftDialog();
  }

  // ============================================================
  // PARTNER LEFT DIALOG
  // ============================================================

  void showPartnerLeftDialog() {
    Future.delayed(
      const Duration(milliseconds: 200),
          () {
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Text('👋'),
                  SizedBox(width: 10),
                  Text('Stranger left'),
                ],
              ),
              content: const Text(
                'The stranger ended the conversation.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'CLOSE',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    startSearching();
                  },
                  icon: const Icon(
                    Icons.person_search,
                  ),
                  label: const Text(
                    'FIND NEW STRANGER',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // START SEARCH
  // ============================================================

  void startSearching() {
    if (!isConnected) {
      showMessage(
        'Connecting to server...',
      );

      if (!isReconnecting) {
        connectToServer(
          autoReconnect: true,
        );
      }

      return;
    }

    manuallyStopped = false;

    setState(() {
      isSearching = true;
      isMatched = false;
      partnerLeft = false;
      strangerTyping = false;
      status = 'Finding a stranger...';

      messages.clear();
      replyingTo = null;
    });

    sendToServer({
      'type': 'start',
    });
  }

  // ============================================================
  // SKIP
  // ============================================================

  void skipStranger() {
    if (!isConnected ||
        !isMatched) {
      return;
    }

    stopTyping();

    setState(() {
      isSearching = true;
      isMatched = false;
      strangerTyping = false;
      partnerLeft = false;
      status = 'Finding another stranger...';

      messages.clear();
      replyingTo = null;
    });

    sendToServer({
      'type': 'skip',
    });
  }

  // ============================================================
  // STOP
  // ============================================================

  void stopSearching() {
    manuallyStopped = true;

    stopTyping();

    sendToServer({
      'type': 'stop',
    });

    setState(() {
      isSearching = false;
      isMatched = false;
      partnerLeft = false;
      strangerTyping = false;
      status = 'Stopped';

      messages.clear();
      replyingTo = null;
    });
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  void sendMessage() {
    final String text = messageController.text.trim();

    if (text.isEmpty || !isMatched) {
      return;
    }

    stopTyping();

    final String clientMessageId =
        'local_${DateTime.now().microsecondsSinceEpoch}';

    final String? replyToId = replyingTo?.id;
    final String? replyToText = replyingTo?.text;

    final ChatMessage message = ChatMessage(
      id: clientMessageId,
      text: text,
      isMine: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      replyToId: replyToId,
      replyToText: replyToText,
    );

    // Add message immediately to our chat.
    setState(() {
      messages.add(message);
      messageController.clear();
      replyingTo = null;
    });

    // Send to server.
    sendToServer({
      'type': 'message',
      'clientMessageId': clientMessageId,
      'text': text,
      'replyTo': replyToId,
    });

    scrollToBottom();
  }

  // ============================================================
  // TYPING
  // ============================================================

  void onTypingChanged(String text) {
    if (!isMatched) {
      return;
    }

    typingTimer?.cancel();

    if (text.trim().isEmpty) {
      stopTyping();
      return;
    }

    if (!isTyping) {
      isTyping = true;

      sendToServer({
        'type': 'typing',
        'typing': true,
      });
    }

    typingTimer = Timer(
      const Duration(seconds: 1),
          () {
        stopTyping();
      },
    );
  }

  void stopTyping() {
    typingTimer?.cancel();

    typingTimer = null;

    if (!isTyping) {
      return;
    }

    isTyping = false;

    sendToServer({
      'type': 'typing',
      'typing': false,
    });
  }

  // ============================================================
  // SEND DATA
  // ============================================================

  void sendToServer(
      Map<String, dynamic> data,
      ) {
    try {
      if (channel == null ||
          !isConnected) {
        return;
      }

      channel!.sink.add(
        jsonEncode(data),
      );
    } catch (e) {
      debugPrint(
        'Send failed: $e',
      );
    }
  }

  // ============================================================
  // REPLY
  // ============================================================

  void setReplyMessage(
      ChatMessage message,
      ) {
    setState(() {
      replyingTo = message;
    });

    FocusScope.of(context)
        .requestFocus(
      FocusNode(),
    );
  }

  void cancelReply() {
    setState(() {
      replyingTo = null;
    });
  }

  // ============================================================
  // COPY
  // ============================================================

  Future<void> copyMessage(
      ChatMessage message,
      ) async {
    await Clipboard.setData(
      ClipboardData(
        text: message.text,
      ),
    );

    if (!mounted) return;

    showMessage(
      'Message copied',
    );
  }

  // ============================================================
  // DELETE LOCALLY
  // ============================================================

  void deleteMessage(
      ChatMessage message,
      ) {
    setState(() {
      messages.remove(message);
    });

    showMessage(
      'Message deleted locally',
    );
  }

  // ============================================================
  // REACTION
  // ============================================================

  void reactToMessage(
      ChatMessage message,
      String emoji,
      ) {
    sendToServer({
      'type': 'reaction',
      'messageId': message.id,
      'emoji': emoji,
    });

    setState(() {
      message.reactions[emoji] =
          (message.reactions[emoji] ?? 0) +
              1;
    });
  }

  // ============================================================
  // MESSAGE MENU
  // ============================================================

  void showMessageMenu(
      ChatMessage message,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
      selectedTheme.background,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.all(15),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                buildReactionRow(
                  message,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.reply,
                  ),
                  title:
                  const Text('Reply'),
                  onTap: () {
                    Navigator.pop(
                      context,
                    );

                    setReplyMessage(
                      message,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.copy,
                  ),
                  title:
                  const Text('Copy'),
                  onTap: () {
                    Navigator.pop(
                      context,
                    );

                    copyMessage(
                      message,
                    );
                  },
                ),
                if (message.isMine)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                    ),
                    title: const Text(
                      'Delete locally',
                    ),
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      deleteMessage(
                        message,
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // REACTION ROW
  // ============================================================

  Widget buildReactionRow(
      ChatMessage message,
      ) {
    const emojis = [
      '❤️',
      '😂',
      '👍',
      '😮',
      '😢',
      '🔥',
    ];

    return Row(
      mainAxisAlignment:
      MainAxisAlignment.spaceEvenly,
      children: emojis.map(
            (emoji) {
          return GestureDetector(
            onTap: () {
              Navigator.pop(
                context,
              );

              reactToMessage(
                message,
                emoji,
              );
            },
            child: Text(
              emoji,
              style: const TextStyle(
                fontSize: 28,
              ),
            ),
          );
        },
      ).toList(),
    );
  }

  // ============================================================
  // REPORT
  // ============================================================

  void showReportDialog() {
    String selectedReason =
        'Spam';

    const reasons = [
      'Spam',
      'Harassment',
      'Sexual content',
      'Hate or abuse',
      'Scam',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder:
              (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Report Stranger',
              ),
              content:
              DropdownButtonFormField<
                  String>(
                value: selectedReason,
                items: reasons
                    .map(
                      (reason) {
                    return DropdownMenuItem(
                      value: reason,
                      child:
                      Text(reason),
                    );
                  },
                )
                    .toList(),
                onChanged:
                    (value) {
                  if (value != null) {
                    setDialogState(() {
                      selectedReason =
                          value;
                    });
                  }
                },
                decoration:
                const InputDecoration(
                  labelText:
                  'Reason',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },
                  child:
                  const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );

                    sendToServer({
                      'type': 'report',
                      'reason':
                      selectedReason,
                    });

                    showMessage(
                      'Report submitted',
                    );
                  },
                  child:
                  const Text('REPORT'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // BLOCK
  // ============================================================

  void showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Block Stranger?',
          ),
          content: const Text(
            'You will be disconnected from this stranger and they will not be matched with you again during this server session.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child:
              const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );

                sendToServer({
                  'type': 'block',
                });

                setState(() {
                  isMatched = false;
                  isSearching = true;
                  strangerTyping = false;
                  messages.clear();
                });
              },
              child:
              const Text('BLOCK'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback(
          (_) {
        if (!scrollController
            .hasClients) {
          return;
        }

        scrollController.animateTo(
          scrollController
              .position
              .maxScrollExtent,
          duration:
          const Duration(
            milliseconds: 250,
          ),
          curve: Curves.easeOut,
        );
      },
    );
  }

  // ============================================================
  // THEME SELECTOR
  // ============================================================

  void showThemeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
      selectedTheme.background,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.all(20),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  '🎨 Chat Theme',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 15,
                ),
                SizedBox(
                  height: 280,
                  child: GridView.builder(
                    itemCount:
                    chatThemes.length,
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.2,
                    ),
                    itemBuilder:
                        (context, index) {
                      final theme =
                      chatThemes[index];

                      final selected =
                          theme.name ==
                              selectedTheme
                                  .name;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedTheme =
                                theme;
                          });

                          Navigator.pop(
                            context,
                          );
                        },
                        child: Container(
                          margin:
                          const EdgeInsets
                              .all(5),
                          decoration:
                          BoxDecoration(
                            color:
                            theme.background,
                            borderRadius:
                            BorderRadius
                                .circular(
                              15,
                            ),
                            border:
                            Border.all(
                              color:
                              selected
                                  ? theme
                                  .primary
                                  : Colors
                                  .grey
                                  .shade800,
                              width:
                              selected
                                  ? 3
                                  : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                theme
                                    .primary,
                                child:
                                const Icon(
                                  Icons.chat,
                                  color:
                                  Colors.white,
                                ),
                              ),
                              const SizedBox(
                                height: 6,
                              ),
                              Text(
                                theme.name,
                                style:
                                const TextStyle(
                                  fontSize:
                                  12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // BACKGROUND SELECTOR
  // ============================================================

  void showBackgroundSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
      selectedTheme.background,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.all(20),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  '🖼️ Chat Background',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 15,
                ),
                ...ChatBackground.values.map(
                      (background) {
                    final selected =
                        selectedBackground ==
                            background;

                    return ListTile(
                      leading:
                      CircleAvatar(
                        backgroundColor:
                        selectedTheme
                            .primary,
                        child:
                        const Icon(
                          Icons
                              .wallpaper,
                        ),
                      ),
                      title: Text(
                        backgroundName(
                          background,
                        ),
                      ),
                      trailing:
                      selected
                          ? Icon(
                        Icons.check,
                        color:
                        selectedTheme
                            .primary,
                      )
                          : null,
                      onTap: () {
                        setState(() {
                          selectedBackground =
                              background;
                        });

                        Navigator.pop(
                          context,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // MORE MENU
  // ============================================================

  void showChatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
      selectedTheme.background,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              ListTile(
                leading:
                const Icon(
                  Icons.palette_outlined,
                ),
                title:
                const Text(
                  'Themes',
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                  );

                  showThemeSelector();
                },
              ),
              ListTile(
                leading:
                const Icon(
                  Icons.wallpaper,
                ),
                title:
                const Text(
                  'Chat Background',
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                  );

                  showBackgroundSelector();
                },
              ),
              ListTile(
                leading:
                const Icon(
                  Icons.flag_outlined,
                ),
                title:
                const Text(
                  'Report Stranger',
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                  );

                  showReportDialog();
                },
              ),
              ListTile(
                leading:
                const Icon(
                  Icons.block,
                ),
                title:
                const Text(
                  'Block Stranger',
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                  );

                  showBlockDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior:
        SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    manuallyStopped = true;

    typingTimer?.cancel();

    reconnectTimer?.cancel();

    socketSubscription?.cancel();

    messageController.dispose();

    scrollController.dispose();

    channel?.sink.close();

    matchAnimationController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(
              Icons.public,
            ),
            SizedBox(
              width: 10,
            ),
            Text(
              'ChitChat',
            ),
          ],
        ),
        actions: [
          if (isReconnecting)
            const Padding(
              padding:
              EdgeInsets.only(
                right: 10,
              ),
              child: SizedBox(
                width: 18,
                height: 18,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          Padding(
            padding:
            const EdgeInsets.only(
              right: 15,
            ),
            child: Center(
              child: Text(
                isConnected
                    ? '🟢 Online'
                    : '🔴 Offline',
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          isMatched
              ? buildChatScreen()
              : buildStartScreen(),

          if (showNewMatchAnimation)
            buildNewMatchAnimation(),
        ],
      ),
    );
  }

  // ============================================================
  // START SCREEN
  // ============================================================

  Widget buildStartScreen() {
    return Center(
      child: SingleChildScrollView(
        padding:
        const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration:
              BoxDecoration(
                shape:
                BoxShape.circle,
                gradient:
                LinearGradient(
                  colors: [
                    selectedTheme
                        .primary
                        .withOpacity(
                      0.9,
                    ),
                    Colors.pinkAccent
                        .withOpacity(
                      0.7,
                    ),
                  ],
                ),
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                size: 65,
                color: Colors.white,
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            const Text(
              'Talk to a Stranger',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            const Text(
              'Meet someone random and start a conversation.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            Container(
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              decoration:
              BoxDecoration(
                color: Colors.green
                    .withOpacity(
                  0.12,
                ),
                borderRadius:
                BorderRadius.circular(
                  20,
                ),
              ),
              child: Text(
                '🟢 $activeUsers people online',
                style:
                const TextStyle(
                  fontSize: 15,
                  color: Colors.green,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            if (isReconnecting)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(
                    height: 12,
                  ),
                  Text(
                    'Reconnecting...',
                  ),
                ],
              )
            else if (isSearching)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(
                    height: 20,
                  ),
                  const Text(
                    'Looking for a stranger...',
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(
                    height: 25,
                  ),
                  OutlinedButton(
                    onPressed:
                    stopSearching,
                    child:
                    const Text(
                      'STOP',
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: 260,
                height: 58,
                child:
                ElevatedButton.icon(
                  onPressed:
                  isConnected
                      ? startSearching
                      : null,
                  icon: const Icon(
                    Icons.play_arrow,
                    size: 28,
                  ),
                  label: const Text(
                    'START',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ),

            const SizedBox(
              height: 25,
            ),

            const Text(
              'No login • Anonymous • Random chat',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NEW MATCH ANIMATION
  // ============================================================

  Widget buildNewMatchAnimation() {
    return Positioned.fill(
      child: Container(
        color: Colors.black
            .withOpacity(
          0.78,
        ),
        child: Center(
          child: ScaleTransition(
            scale:
            matchScaleAnimation,
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration:
                  BoxDecoration(
                    shape:
                    BoxShape.circle,
                    color: selectedTheme
                        .primary,
                    boxShadow: [
                      BoxShadow(
                        color:
                        selectedTheme
                            .primary
                            .withOpacity(
                          0.6,
                        ),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_search,
                    size: 55,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(
                  height: 25,
                ),
                const Text(
                  '✨ Stranger Found!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                const Text(
                  'Say hello 👋',
                  style:
                  TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CHAT SCREEN
  // ============================================================

  Widget buildChatScreen() {
    return Container(
      decoration:
      buildBackgroundDecoration(),
      child: Column(
        children: [
          buildChatHeader(),

          Expanded(
            child:
            ListView.builder(
              controller:
              scrollController,
              padding:
              const EdgeInsets.all(
                15,
              ),
              itemCount:
              messages.length,
              itemBuilder:
                  (context, index) {
                return buildMessage(
                  messages[index],
                );
              },
            ),
          ),

          if (strangerTyping)
            buildTypingIndicator(),

          buildReplyPreview(),

          buildMessageInput(),
        ],
      ),
    );
  }

  // ============================================================
  // BACKGROUND
  // ============================================================

  BoxDecoration buildBackgroundDecoration() {
    switch (selectedBackground) {
      case ChatBackground.solid:
        return BoxDecoration(
          color:
          selectedTheme.background,
        );

      case ChatBackground.gradient:
        return BoxDecoration(
          gradient:
          LinearGradient(
            begin:
            Alignment.topLeft,
            end:
            Alignment.bottomRight,
            colors: [
              selectedTheme
                  .background,
              selectedTheme.primary
                  .withOpacity(
                0.20,
              ),
            ],
          ),
        );

      case ChatBackground.midnight:
        return const BoxDecoration(
          gradient:
          LinearGradient(
            colors: [
              Color(0xFF020617),
              Color(0xFF0F172A),
              Color(0xFF111827),
            ],
          ),
        );

      case ChatBackground.galaxy:
        return const BoxDecoration(
          gradient:
          LinearGradient(
            begin:
            Alignment.topLeft,
            end:
            Alignment.bottomRight,
            colors: [
              Color(0xFF0B0220),
              Color(0xFF2B0A4A),
              Color(0xFF090B2A),
            ],
          ),
        );

      case ChatBackground.ocean:
        return const BoxDecoration(
          gradient:
          LinearGradient(
            colors: [
              Color(0xFF001F3F),
              Color(0xFF003B5C),
              Color(0xFF001219),
            ],
          ),
        );

      case ChatBackground.sunset:
        return const BoxDecoration(
          gradient:
          LinearGradient(
            begin:
            Alignment.topLeft,
            end:
            Alignment.bottomRight,
            colors: [
              Color(0xFF3B0A2A),
              Color(0xFF7F1D1D),
              Color(0xFF1F2937),
            ],
          ),
        );

      case ChatBackground.hearts:
        return BoxDecoration(
          color:
          selectedTheme.background,
          image:
          const DecorationImage(
            image: AssetImage(
              'assets/chat/hearts.png',
            ),
            repeat:
            ImageRepeat.repeat,
            opacity: 0.08,
          ),
        );

      case ChatBackground.bubbles:
        return BoxDecoration(
          color:
          selectedTheme.background,
        );
    }
  }

  // ============================================================
  // CHAT HEADER
  // ============================================================

  Widget buildChatHeader() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(10),
      decoration:
      BoxDecoration(
        color: selectedTheme.primary
            .withOpacity(
          0.20,
        ),
        border: Border(
          bottom:
          BorderSide(
            color:
            Colors.grey.shade800,
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
            selectedTheme.primary,
            child: const Icon(
              Icons.person,
              color: Colors.white,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                const Text(
                  'Stranger',
                  style:
                  TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    const Text(
                      '🟢 Connected',
                      style:
                      TextStyle(
                        color:
                        Colors.green,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Text(
                      '$activeUsers online',
                      style:
                      const TextStyle(
                        color:
                        Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          IconButton(
            onPressed:
            showBackgroundSelector,
            icon:
            const Icon(
              Icons.wallpaper,
            ),
            tooltip:
            'Background',
          ),

          IconButton(
            onPressed:
            showChatMenu,
            icon:
            const Icon(
              Icons.more_vert,
            ),
            tooltip:
            'More',
          ),

          OutlinedButton(
            onPressed:
            skipStranger,
            child:
            const Text('SKIP'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  Widget buildMessage(
      ChatMessage message,
      ) {
    return Align(
      alignment:
      message.isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Dismissible(
        key: ValueKey(
          message.id,
        ),
        direction:
        DismissDirection
            .horizontal,
        confirmDismiss:
            (direction) async {
          setReplyMessage(
            message,
          );

          return false;
        },
        background:
        buildSwipeReplyBackground(
          true,
        ),
        secondaryBackground:
        buildSwipeReplyBackground(
          false,
        ),
        child: GestureDetector(
          onLongPress: () {
            showMessageMenu(
              message,
            );
          },
          child: Container(
            constraints:
            const BoxConstraints(
              maxWidth: 340,
            ),
            margin:
            const EdgeInsets.only(
              bottom: 8,
            ),
            padding:
            const EdgeInsets
                .symmetric(
              horizontal: 14,
              vertical: 9,
            ),
            decoration:
            BoxDecoration(
              color:
              message.isMine
                  ? selectedTheme
                  .myMessage
                  : selectedTheme
                  .strangerMessage,
              borderRadius:
              BorderRadius.circular(
                18,
              ),
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                if (message
                    .replyToText !=
                    null)
                  buildQuotedReply(
                    message,
                  ),

                Text(
                  message.text,
                  style:
                  const TextStyle(
                    fontSize: 16,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Row(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    Text(
                      formatTime(
                        message
                            .timestamp,
                      ),
                      style:
                      const TextStyle(
                        fontSize: 10,
                        color:
                        Colors.white54,
                      ),
                    ),

                    if (message.isMine)
                      Padding(
                        padding:
                        const EdgeInsets
                            .only(
                          left: 5,
                        ),
                        child:
                        buildMessageStatus(
                          message,
                        ),
                      ),
                  ],
                ),

                if (message
                    .reactions
                    .isNotEmpty)
                  buildReactions(
                    message,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SWIPE REPLY BACKGROUND
  // ============================================================

  Widget buildSwipeReplyBackground(
      bool left,
      ) {
    return Align(
      alignment:
      left
          ? Alignment.centerLeft
          : Alignment.centerRight,
      child: Padding(
        padding:
        const EdgeInsets
            .symmetric(
          horizontal: 20,
        ),
        child: Icon(
          Icons.reply,
          color:
          selectedTheme.primary,
        ),
      ),
    );
  }

  // ============================================================
  // QUOTED REPLY
  // ============================================================

  Widget buildQuotedReply(
      ChatMessage message,
      ) {
    return Container(
      width: double.infinity,
      margin:
      const EdgeInsets.only(
        bottom: 7,
      ),
      padding:
      const EdgeInsets.all(7),
      decoration:
      BoxDecoration(
        color: Colors.black
            .withOpacity(
          0.18,
        ),
        borderRadius:
        BorderRadius.circular(
          8,
        ),
      ),
      child: Text(
        message.replyToText ??
            '',
        maxLines: 2,
        overflow:
        TextOverflow.ellipsis,
        style:
        const TextStyle(
          fontSize: 12,
          color:
          Colors.white70,
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE STATUS
  // ============================================================

  Widget buildMessageStatus(
      ChatMessage message,
      ) {
    switch (message.status) {
      case MessageStatus.sending:
        return const Icon(
          Icons.access_time,
          size: 12,
          color: Colors.white54,
        );

      case MessageStatus.sent:
        return const Icon(
          Icons.check,
          size: 13,
          color: Colors.white70,
        );

      case MessageStatus.delivered:
        return const Icon(
          Icons.done_all,
          size: 13,
          color: Colors.lightBlueAccent,
        );
    }
  }

  // ============================================================
  // REACTIONS
  // ============================================================

  Widget buildReactions(
      ChatMessage message,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        top: 5,
      ),
      child: Wrap(
        spacing: 3,
        children: message
            .reactions.entries
            .map(
              (entry) {
            return Container(
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration:
              BoxDecoration(
                color: Colors.black
                    .withOpacity(
                  0.20,
                ),
                borderRadius:
                BorderRadius
                    .circular(
                  10,
                ),
              ),
              child: Text(
                '${entry.key} ${entry.value}',
                style:
                const TextStyle(
                  fontSize: 11,
                ),
              ),
            );
          },
        )
            .toList(),
      ),
    );
  }

  // ============================================================
  // TYPING INDICATOR
  // ============================================================

  Widget buildTypingIndicator() {
    return Align(
      alignment:
      Alignment.centerLeft,
      child: Container(
        margin:
        const EdgeInsets.only(
          left: 15,
          bottom: 7,
        ),
        padding:
        const EdgeInsets
            .symmetric(
          horizontal: 15,
          vertical: 9,
        ),
        decoration:
        BoxDecoration(
          color: selectedTheme
              .strangerMessage,
          borderRadius:
          BorderRadius.circular(
            18,
          ),
        ),
        child:
        const TypingDots(),
      ),
    );
  }

  // ============================================================
  // REPLY PREVIEW
  // ============================================================

  Widget buildReplyPreview() {
    if (replyingTo == null) {
      return const SizedBox();
    }

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets
          .symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration:
      BoxDecoration(
        color:
        selectedTheme.primary
            .withOpacity(
          0.15,
        ),
        border:
        Border(
          left: BorderSide(
            color:
            selectedTheme.primary,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            color:
            selectedTheme.primary,
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              replyingTo!.text,
              maxLines: 2,
              overflow:
              TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed:
            cancelReply,
            icon:
            const Icon(
              Icons.close,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE INPUT
  // ============================================================

  Widget buildMessageInput() {
    return SafeArea(
      child: Padding(
        padding:
        const EdgeInsets.all(
          10,
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                showEmojiPicker();
              },
              icon:
              const Icon(
                Icons.emoji_emotions_outlined,
              ),
            ),

            Expanded(
              child: TextField(
                controller:
                messageController,
                textInputAction:
                TextInputAction.send,
                onChanged:
                onTypingChanged,
                onSubmitted: (_) {
                  sendMessage();
                },
                decoration:
                InputDecoration(
                  hintText:
                  'Type a message...',
                  filled: true,
                  fillColor:
                  Colors.black
                      .withOpacity(
                    0.20,
                  ),
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                      25,
                    ),
                    borderSide:
                    BorderSide.none,
                  ),
                  focusedBorder:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                      25,
                    ),
                    borderSide:
                    BorderSide(
                      color:
                      selectedTheme
                          .primary,
                    ),
                  ),
                  contentPadding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(
              width: 7,
            ),

            CircleAvatar(
              radius: 24,
              backgroundColor:
              selectedTheme.primary,
              child: IconButton(
                onPressed:
                sendMessage,
                icon:
                const Icon(
                  Icons.send,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMOJI PICKER
  // ============================================================

  void showEmojiPicker() {
    const emojis = [
      '😀',
      '😂',
      '🤣',
      '😊',
      '😍',
      '🥰',
      '😘',
      '😎',
      '🤔',
      '😮',
      '😢',
      '😭',
      '😡',
      '🤯',
      '🥳',
      '❤️',
      '🔥',
      '👍',
      '👎',
      '👏',
      '🙏',
      '🎉',
      '💯',
      '✨',
      '👋',
      '💜',
      '💙',
      '💚',
      '🤣',
      '😴',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor:
      selectedTheme.background,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.all(
              15,
            ),
            child: GridView.builder(
              shrinkWrap: true,
              itemCount:
              emojis.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              ),
              itemBuilder:
                  (context, index) {
                return InkWell(
                  onTap: () {
                    messageController
                        .text +=
                    emojis[index];

                    messageController
                        .selection =
                        TextSelection
                            .fromPosition(
                          TextPosition(
                            offset:
                            messageController
                                .text
                                .length,
                          ),
                        );

                    Navigator.pop(
                      context,
                    );

                    onTypingChanged(
                      messageController
                          .text,
                    );
                  },
                  child: Center(
                    child: Text(
                      emojis[index],
                      style:
                      const TextStyle(
                        fontSize: 26,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // TIME
  // ============================================================

  String formatTime(
      DateTime time,
      ) {
    final hour =
    time.hour % 12 == 0
        ? 12
        : time.hour % 12;

    final minute =
    time.minute
        .toString()
        .padLeft(
      2,
      '0',
    );

    final period =
    time.hour >= 12
        ? 'PM'
        : 'AM';

    return '$hour:$minute $period';
  }
}

// ============================================================
// TYPING DOTS
// ============================================================

class TypingDots
    extends StatefulWidget {
  const TypingDots({
    super.key,
  });

  @override
  State<TypingDots> createState() =>
      _TypingDotsState();
}

class _TypingDotsState
    extends State<TypingDots>
    with SingleTickerProviderStateMixin {

  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller =
    AnimationController(
      vsync: this,
      duration:
      const Duration(
        milliseconds: 1000,
      ),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        const Text(
          'Stranger is typing',
          style:
          TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(
          width: 5,
        ),
        AnimatedBuilder(
          animation:
          controller,
          builder:
              (context, child) {
            final dots =
                ((controller.value *
                    3)
                    .floor() %
                    3) +
                    1;

            return SizedBox(
              width: 18,
              child: Text(
                '.' * dots,
                style:
                const TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}