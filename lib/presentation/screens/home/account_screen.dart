import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/account/account_sync.dart';
import '../../../data/account/auth_service.dart';
import '../../../data/providers/theme_provider.dart';

/// Conta (a mesma do site): entrar, criar conta, sair e excluir.
/// Com [start], é a primeira tela do app para quem não está logado.
class AccountScreen extends StatefulWidget {
  final bool start;
  const AccountScreen({super.key, this.start = false});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (done != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir conta"),
        content: const Text("Os decks, o perfil e o nível da conta serão apagados para sempre, no app e no site. Continuar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );
    if (ok == true) await _run(AccountSync.instance.deleteAccount, done: "Conta excluída.");
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final auth = context.watch<AuthService>();
    final bg = theme.backgroundColor;
    final isLight = bg.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;
    final fieldFill = isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white10;

    InputDecoration field(String label, IconData icon) => InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textColor.withValues(alpha: 0.6)),
          prefixIcon: Icon(icon, color: textColor.withValues(alpha: 0.6)),
          filled: true,
          fillColor: fieldFill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        );

    Widget body;
    switch (auth.status) {
      case AuthStatus.disabled:
        body = Text(
          "O login ainda não foi configurado nesta versão do app.\nTudo continua salvo neste aparelho.",
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor.withValues(alpha: 0.7)),
        );
      case AuthStatus.loading:
        body = const Center(child: CircularProgressIndicator());
      case AuthStatus.signedIn:
        final u = auth.user!;
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.blueAccent,
            backgroundImage: u.photo != null ? NetworkImage(u.photo!) : null,
            child: u.photo == null ? Text((u.name ?? u.email ?? '?').substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 28, color: Colors.white)) : null,
          ),
          const SizedBox(height: 12),
          Text(u.name ?? '', textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(u.email ?? '', textAlign: TextAlign.center, style: TextStyle(color: textColor.withValues(alpha: 0.6))),
          const SizedBox(height: 20),
          Text(
            "Seus decks, perfil, nível, missões, preferências e a partida do contador ficam na conta. O que você muda aqui aparece no site na hora, e vice-versa.",
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text("Sair da conta"),
            onPressed: _busy ? null : () => _run(AccountSync.instance.logout),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : _confirmDelete,
            child: const Text("Excluir conta", style: TextStyle(color: Colors.redAccent)),
          ),
        ]);
      case AuthStatus.signedOut:
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            "Entre para usar os mesmos decks e o mesmo perfil no app e no site.",
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87, minimumSize: const Size(0, 50)),
            icon: const Icon(Icons.g_mobiledata, size: 32),
            label: const Text("Entrar com Google", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _busy ? null : () => _run(auth.signInWithGoogle),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: Divider(color: textColor.withValues(alpha: 0.2))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text("ou com e-mail", style: TextStyle(color: textColor.withValues(alpha: 0.5)))),
            Expanded(child: Divider(color: textColor.withValues(alpha: 0.2))),
          ]),
          const SizedBox(height: 16),
          if (_creating) ...[
            TextField(controller: _name, style: TextStyle(color: textColor), decoration: field("Seu nome", Icons.person)),
            const SizedBox(height: 10),
          ],
          TextField(controller: _email, style: TextStyle(color: textColor), keyboardType: TextInputType.emailAddress, decoration: field("E-mail", Icons.email)),
          const SizedBox(height: 10),
          TextField(controller: _password, style: TextStyle(color: textColor), obscureText: true, decoration: field("Senha", Icons.lock)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, minimumSize: const Size(0, 50)),
            onPressed: _busy
                ? null
                : () => _run(() => _creating
                    ? auth.signUp(name: _name.text, email: _email.text, password: _password.text)
                    : auth.signIn(email: _email.text, password: _password.text)),
            child: Text(_creating ? "CRIAR CONTA" : "ENTRAR", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => setState(() {
              _creating = !_creating;
              _error = null;
            }),
            child: Text(_creating ? "Já tenho conta: entrar" : "Não tenho conta: criar"),
          ),
          if (!_creating)
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (_email.text.trim().isEmpty) {
                        setState(() => _error = "Digite o seu e-mail para receber o link de nova senha.");
                        return;
                      }
                      _run(() => auth.resetPassword(_email.text), done: "Enviamos um link para criar uma nova senha.");
                    },
              child: Text("Esqueci a senha", style: TextStyle(color: textColor.withValues(alpha: 0.6))),
            ),
        ]);
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(widget.start ? "LIFELINK" : "CONTA", style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        centerTitle: widget.start,
        automaticallyImplyLeading: !widget.start,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (widget.start) ...[
              Center(child: Image.asset('assets/logo/lifelink.png', width: 120, height: 120)),
              const SizedBox(height: 24),
            ],
            body,
            if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
      ),
    );
  }
}
