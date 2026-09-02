import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String dealId;
  const ChatScreen({super.key, required this.dealId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  late final Stream<DocumentSnapshot> _tripStream;
  late final Stream<QuerySnapshot> _messagesStream;

  @override
  void initState() {
    super.initState();
    _tripStream = FirebaseFirestore.instance.collection('trips').doc(widget.dealId).snapshots();
    _messagesStream = FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.dealId)
        .collection('chat_messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    final appState = ref.read(appStateProvider);
    _sending = true;
    _msgCtrl.clear();

    try {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.dealId)
          .collection('chat_messages')
          .add({
        'text': text,
        // Identidad por UID (no por nombre) para no confundir remitentes.
        'senderUid': appState.uid,
        'senderName': appState.userName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Si falla el envío, restaurar el texto y avisar (no perder el mensaje).
      _msgCtrl.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el mensaje. Intenta de nuevo.')),
        );
      }
    } finally {
      _sending = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text('Coordinación', style: AppTheme.bodyFont(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
            Text('Trato #${widget.dealId}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _tripStream,
        builder: (context, tripSnapshot) {
          if (!tripSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.black));
          
          final tripData = tripSnapshot.data!.data() as Map<String, dynamic>?;
          if (tripData == null) return const Center(child: Text('Trato no encontrado'));

          final bool isAccepted = tripData['status'] == 'ACCEPTED';

          return Column(
            children: [
              if (isAccepted) _buildConfirmationBanner(tripData),
              Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error cargando mensajes'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.black));
                }

                final messages = snapshot.data!.docs;
                final currentUid = ref.read(appStateProvider).uid;

                if (messages.isEmpty) {
                  return const Center(child: Text('Inicia la conversación', style: TextStyle(color: Colors.black45)));
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final text = msg['text'] ?? '';
                    final senderUid = msg['senderUid'];
                    final isMe = senderUid == currentUid;
                    return _buildMessage(text, isMe);
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
              color: Colors.white,
            ),
            child: SafeArea(
              child: Row(
                children: [
                  const Icon(Icons.add, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Escribe un mensaje',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: const CircleAvatar(
                      backgroundColor: Colors.black,
                      radius: 16,
                      child: Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      );
      },
      ),
    );
  }

  Widget _buildConfirmationBanner(Map<String, dynamic> tripData) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Text('Viaje Confirmado', style: AppTheme.bodyFont(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Encuentro: ${tripData['exactPickup']}', style: AppTheme.bodyFont(color: Colors.black87, fontSize: 13)),
          Text('Destino: ${tripData['exactDropoff']}', style: AppTheme.bodyFont(color: Colors.black87, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        backgroundColor: Colors.white,
                        title: Text('Cancelar Viaje', style: AppTheme.bodyFont(fontWeight: FontWeight.bold, color: Colors.black)),
                        content: Text('¿Estás seguro que deseas cancelar este viaje?', style: AppTheme.bodyFont(color: Colors.black87)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text('No, mantener', style: AppTheme.bodyFont(color: Colors.black54)),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(dialogContext); // Close dialog
                              await FirebaseFirestore.instance.collection('trips').doc(widget.dealId).update({
                                'status': 'CANCELLED'
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viaje cancelado exitosamente')));
                                context.pop(); // Go back to previous screen
                              }
                            },
                            child: Text('Sí, cancelar', style: AppTheme.bodyFont(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black54,
                    side: const BorderSide(color: Colors.black12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    context.push('/tracking/${widget.dealId}');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Comenzar'),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMessage(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? Colors.black : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(18),
        ),
        constraints: const BoxConstraints(maxWidth: 250),
        child: Text(
          text,
          style: AppTheme.bodyFont(color: isMe ? Colors.white : Colors.black87, fontSize: 15),
        ),
      ),
    );
  }
}
