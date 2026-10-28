import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/account/auth_service.dart';
import '../../../data/account/online.dart';
import '../../../data/providers/deck_provider.dart';
import '../../../data/providers/collection_provider.dart';
import '../../../data/providers/game_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/services/scryfall_service.dart';
import '../../theme/app_theme.dart';

String _message(Object e) {
  final text = e.toString().replaceFirst('Exception: ', '');
  if (text.contains('permission-denied') || text.contains('PERMISSION_DENIED')) {
    return 'O servidor recusou. As regras do banco (firestore.rules) precisam ser publicadas de novo no Firebase.';
  }
  return text;
}

/// Mesa online: criar uma mesa (com código), entrar com um código, os
/// convites dos amigos e convidar amigos para a mesa.
class OnlineTableDialog extends StatefulWidget {
  final GameProvider game;
  const OnlineTableDialog({super.key, required this.game});

  @override
  State<OnlineTableDialog> createState() => _OnlineTableDialogState();
}

class _OnlineTableDialogState extends State<OnlineTableDialog> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } catch (e) {
      _error = _message(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final table = OnlineTable.instance;
    final signedIn = AuthService.instance.status == AuthStatus.signedIn;
    return AnimatedBuilder(
      animation: table,
      builder: (context, _) => AlertDialog(
        title: Text('Mesa online', style: TextStyle(color: LL.ink)),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!signedIn)
                Text('Entre na conta (menu do início → Conta) para jogar com a mesa online.', style: TextStyle(color: LL.ink.withValues(alpha: 0.70)))
              else if (table.active) ...[
                Text('Cada um entra com este código no próprio celular (ou no site) e a vida de todos aparece em todos.',
                    style: TextStyle(color: LL.ink.withValues(alpha: 0.54), fontSize: 13)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: table.code!));
                    setState(() => _info = 'Código copiado.');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: LL.ink.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16)),
                    child: Text(table.code!, textAlign: TextAlign.center, style: TextStyle(color: LL.ink, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: 6)),
                  ),
                ),
                const SizedBox(height: 12),
                Text('MEU LUGAR', style: TextStyle(color: LL.ink.withValues(alpha: 0.54), fontSize: 12, fontWeight: FontWeight.w800)),
                Text('Cada um no seu celular: o seu quadro fica grande e os dos outros pequenos, todos de frente para você.',
                    style: TextStyle(color: LL.ink.withValues(alpha: 0.38), fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  ChoiceChip(label: const Text('Mesa inteira'), selected: table.mySeat < 0, onSelected: (_) => table.setMySeat(-1)),
                  for (int i = 0; i < widget.game.playerCount; i++)
                    ChoiceChip(label: Text(widget.game.playerNames[i]), selected: table.mySeat == i, onSelected: (_) => table.setMySeat(i)),
                ]),
                const SizedBox(height: 12),
                Text('CONVIDAR AMIGO', style: TextStyle(color: LL.ink.withValues(alpha: 0.54), fontSize: 12, fontWeight: FontWeight.w800)),
                StreamBuilder<List<Friend>>(
                  stream: Friends.instance.friends(),
                  builder: (context, snap) {
                    final friends = [for (final f in snap.data ?? const <Friend>[]) if (f.accepted) f];
                    if (friends.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('Sem amigos ainda (menu do início → Amigos).', style: TextStyle(color: LL.ink.withValues(alpha: 0.38), fontSize: 13)),
                      );
                    }
                    return Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final f in friends)
                        ActionChip(
                          avatar: const Icon(Icons.send, size: 16),
                          label: Text(f.nick),
                          onPressed: () => _run(() async {
                            await Friends.instance.invite(f, table.code!);
                            _info = 'Convite enviado para ${f.nick}.';
                          }),
                        ),
                    ]);
                  },
                ),
              ] else ...[
                if (table.error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(table.error!, style: const TextStyle(color: Color(0xFFFFCC80)))),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _run(() async => table.create(widget.game)),
                  icon: const Icon(Icons.add),
                  label: const Text('Criar mesa com esta partida'),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      style: TextStyle(color: LL.ink, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 3),
                      decoration: InputDecoration(hintText: 'CÓDIGO', hintStyle: TextStyle(color: LL.ink.withValues(alpha: 0.24)), counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _busy ? null : () => _run(() => table.join(widget.game, _code.text)), child: const Text('Entrar')),
                ]),
                const SizedBox(height: 10),
                StreamBuilder<List<({String code, String from})>>(
                  stream: Friends.instance.invites(),
                  builder: (context, snap) {
                    final invites = snap.data ?? const [];
                    if (invites.isEmpty) return const SizedBox.shrink();
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('CONVITES', style: TextStyle(color: LL.ink.withValues(alpha: 0.54), fontSize: 12, fontWeight: FontWeight.w800)),
                      for (final i in invites)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.mail, color: Colors.amber),
                          title: Text('${i.from} chamou para a mesa ${i.code}', style: TextStyle(color: LL.ink)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: Icon(Icons.close, color: LL.ink.withValues(alpha: 0.38)), onPressed: () => Friends.instance.dismissInvite(i.code)),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                        await table.join(widget.game, i.code);
                                        await Friends.instance.dismissInvite(i.code);
                                      }),
                              child: const Text('Entrar'),
                            ),
                          ]),
                        ),
                    ]);
                  },
                ),
                Text('Ao entrar numa mesa, a partida deste celular vira a da mesa.', style: TextStyle(color: LL.ink.withValues(alpha: 0.38), fontSize: 12)),
              ],
              if (_busy) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Color(0xFFFF8A80)))),
              if (_info != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_info!, style: const TextStyle(color: Color(0xFFB9F6CA)))),
            ]),
          ),
        ),
        actions: [
          if (table.active)
            TextButton(
              onPressed: () => table.leave(),
              child: Text(table.isOwner ? 'Fechar a mesa' : 'Sair da mesa', style: const TextStyle(color: Color(0xFFFF8A80))),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }
}

/// Amigos pelo nick: pedir, aceitar e ver os decks deles.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _nick = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _ok = true;

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      _msg = await Friends.instance.add(_nick.text);
      _ok = true;
      _nick.clear();
    } catch (e) {
      _msg = _message(e);
      _ok = false;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final auth = context.watch<AuthService>();
    final light = theme.backgroundColor.computeLuminance() > 0.5;
    final text = light ? Colors.black87 : Colors.white;
    Widget title(String t) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(t, style: TextStyle(color: text.withValues(alpha: 0.55), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
        );

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(title: Text('Amigos', style: TextStyle(color: text)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: text)),
      body: auth.status != AuthStatus.signedIn
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Entre na conta para adicionar amigos pelo nick.', textAlign: TextAlign.center, style: TextStyle(color: text))))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text('Seu nick: ${auth.user?.name ?? ''}', style: TextStyle(color: text, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _nick,
                    style: TextStyle(color: text),
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(hintText: 'Nick do amigo', hintStyle: TextStyle(color: text.withValues(alpha: 0.4)), prefixIcon: const Icon(Icons.person_add)),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _busy ? null : _add, child: const Text('Adicionar')),
              ]),
              if (_msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!, style: TextStyle(color: _ok ? Colors.green : Colors.redAccent))),
              StreamBuilder<List<Friend>>(
                stream: Friends.instance.requests(),
                builder: (context, snap) {
                  final requests = snap.data ?? const [];
                  if (requests.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    title('PEDIDOS DE AMIZADE'),
                    for (final r in requests)
                      Card(
                        child: ListTile(
                          leading: Icon(Icons.mail, color: LL.gold),
                          title: Text(r.nick),
                          subtitle: const Text('quer ser seu amigo'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.close), tooltip: 'Recusar', onPressed: () => Friends.instance.decline(r)),
                            IconButton(icon: const Icon(Icons.check, color: Colors.green), tooltip: 'Aceitar', onPressed: () => Friends.instance.accept(r)),
                          ]),
                        ),
                      ),
                  ]);
                },
              ),
              title('AMIGOS'),
              StreamBuilder<List<Friend>>(
                stream: Friends.instance.friends(),
                builder: (context, snap) {
                  if (snap.hasError) return Text(_message(snap.error!), style: const TextStyle(color: Colors.redAccent));
                  final friends = snap.data;
                  if (friends == null) return const Center(child: CircularProgressIndicator());
                  if (friends.isEmpty) return Text('Nenhum amigo ainda. Adicione pelo nick.', style: TextStyle(color: text.withValues(alpha: 0.55)));
                  return Column(children: [
                    for (final f in friends)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text(f.nick.isEmpty ? '?' : f.nick[0].toUpperCase())),
                          title: Text(f.nick),
                          subtitle: Text(f.accepted ? 'Toque para ver os decks e as trocas' : 'Esperando aceitar o pedido'),
                          onTap: f.accepted ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => FriendDecksScreen(friend: f))) : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.person_remove_outlined),
                            tooltip: 'Tirar dos amigos',
                            onPressed: () => Friends.instance.remove(f),
                          ),
                        ),
                      ),
                  ]);
                },
              ),
            ]),
    );
  }
}

/// Os decks de um amigo: ver as cartas e copiar para os meus decks.
class FriendDecksScreen extends StatelessWidget {
  final Friend friend;
  const FriendDecksScreen({super.key, required this.friend});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final light = theme.backgroundColor.computeLuminance() > 0.5;
    final text = light ? Colors.black87 : Colors.white;
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(title: Text('${friend.nick}: decks e trocas', style: TextStyle(color: text)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: text)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: Friends.instance.decksOf(friend),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_message(snap.error!), textAlign: TextAlign.center, style: TextStyle(color: text))));
          final decks = snap.data;
          if (decks == null) return const Center(child: CircularProgressIndicator());
          return ListView(padding: const EdgeInsets.all(12), children: [
            _TradeWith(friend: friend, text: text),
            if (decks.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text('${friend.nick} ainda não tem decks.', textAlign: TextAlign.center, style: TextStyle(color: text))),
            for (final d in decks)
              () {
                final cards = [for (final c in (d['cards'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)];
                return Card(
                  child: ExpansionTile(
                    leading: cards.isEmpty
                        ? const Icon(Icons.style)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(imageUrl: '${cards.first['imageUrl'] ?? ''}', httpHeaders: CardImages.headers, width: 36, fit: BoxFit.cover, errorWidget: (_, _, _) => const Icon(Icons.style)),
                          ),
                    title: Text('${d['name'] ?? 'Deck'}'),
                    subtitle: Text('${d['type'] ?? ''} · ${cards.length} cartas'),
                    children: [
                      SizedBox(
                        height: 150,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: cards.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(imageUrl: '${cards[i]['imageUrl'] ?? ''}', httpHeaders: CardImages.headers, width: 104, fit: BoxFit.cover, errorWidget: (_, _, _) => const SizedBox(width: 104)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: FilledButton.icon(
                          onPressed: () {
                            context.read<DeckProvider>().importDeck('${d['name'] ?? 'Deck'} (de ${friend.nick})', '${d['type'] ?? 'Normal'}', cards);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deck copiado para os seus decks!')));
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copiar para os meus decks'),
                        ),
                      ),
                    ],
                  ),
                );
              }(),
          ]);
        },
      ),
    );
  }
}

/// As trocas possíveis com o amigo: o que ele tem para troca e está na minha
/// lista de desejos, e o que eu tenho para troca e ele quer.
class _TradeWith extends StatelessWidget {
  final Friend friend;
  final Color text;
  const _TradeWith({required this.friend, required this.text});

  @override
  Widget build(BuildContext context) {
    final collection = context.watch<CollectionProvider>();
    return FutureBuilder(
      future: Friends.instance.tradeOf(friend),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) return const SizedBox.shrink();
        final m = collection.matches(data.trade, data.wish);
        Widget list(String title, List<Map<String, dynamic>> cards, String empty) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: text.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              if (cards.isEmpty) Text(empty, style: TextStyle(color: text.withValues(alpha: 0.45), fontSize: 13)),
              for (final c in cards)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: CachedNetworkImage(imageUrl: '${c['img'] ?? ''}', httpHeaders: CardImages.headers, width: 30, height: 42, fit: BoxFit.cover, errorWidget: (_, _, _) => const SizedBox(width: 30)),
                  ),
                  title: Text('${c['name']}', style: TextStyle(color: text, fontWeight: FontWeight.w700)),
                  subtitle: Text('${c['set'] ?? ''} · US\$ ${((c['usd'] as num?) ?? 0).toStringAsFixed(2)}', style: TextStyle(color: text.withValues(alpha: 0.55))),
                ),
              const SizedBox(height: 8),
            ]);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(Icons.swap_horiz, color: LL.gold),
                const SizedBox(width: 8),
                Text('Trocas com ${friend.nick}', style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 10),
              list('${friend.nick.toUpperCase()} TEM PARA TROCA E VOCÊ QUER', m.theyHave, 'Nada da sua lista de desejos.'),
              list('VOCÊ TEM PARA TROCA E ${friend.nick.toUpperCase()} QUER', m.iHave, 'Nada da lista de desejos de ${friend.nick}. Marque cartas "para troca" na sua coleção.'),
              Text('${data.trade.length} carta(s) para troca · ${data.wish.length} na lista de desejos', style: TextStyle(color: text.withValues(alpha: 0.45), fontSize: 12)),
            ]),
          ),
        );
      },
    );
  }
}
