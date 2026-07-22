import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xxread/services/sync/sync_models.dart';
import 'package:xxread/services/sync/webdav_sync_controller.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';

import 'webdav_sync_translator.dart';

class WebDavSetupPage extends StatefulWidget {
  const WebDavSetupPage({super.key});

  @override
  State<WebDavSetupPage> createState() => _WebDavSetupPageState();
}

class _WebDavSetupPageState extends State<WebDavSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rootController = TextEditingController(text: 'OpenReading');

  var _obscurePassword = true;
  var _testing = false;
  var _saving = false;
  var _connectionVerified = false;
  WebDavSyncErrorCode? _connectionError;
  late WebDavSyncScope _scope;

  @override
  void initState() {
    super.initState();
    final sync = context.read<WebDavSyncController>();
    _serverController.text = sync.serverUrl ?? '';
    _usernameController.text = sync.username ?? '';
    _rootController.text = sync.rootPath ?? 'OpenReading';
    _scope = sync.scope;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootController.dispose();
    super.dispose();
  }

  WebDavSyncConfigDraft get _draft => WebDavSyncConfigDraft(
        serverUrl: _serverController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        rootPath: _rootController.text.trim(),
      );

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _testing = true;
      _connectionVerified = false;
      _connectionError = null;
    });
    final result =
        await context.read<WebDavSyncController>().testConnection(_draft);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _connectionVerified = result.success;
      _connectionError = result.errorCode;
    });
  }

  Future<void> _save() async {
    if (!_connectionVerified || _saving) return;
    setState(() => _saving = true);
    final sync = context.read<WebDavSyncController>();
    await sync.configure(_draft);
    await sync.setScope(_scope);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  void _invalidateTest([String? _]) {
    if (_connectionVerified || _connectionError != null) {
      setState(() {
        _connectionVerified = false;
        _connectionError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = PageStyleHelper.palette(context);
    final sync = context.watch<WebDavSyncController>();
    final hasStoredConfiguration = sync.isConfigured;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.webDavSetUp)),
      body: Container(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionCard(
                          title: l10n.webDavConnectionTitle,
                          icon: Icons.cloud_outlined,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _serverController,
                                keyboardType: TextInputType.url,
                                autofillHints: const [AutofillHints.url],
                                decoration: InputDecoration(
                                  labelText: l10n.webDavServerUrl,
                                  prefixIcon: const Icon(Icons.link_rounded),
                                ),
                                onChanged: _invalidateTest,
                                validator: (value) {
                                  final uri = Uri.tryParse(value?.trim() ?? '');
                                  return uri != null && uri.host.isNotEmpty
                                      ? null
                                      : l10n.webDavErrorUnknown;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _usernameController,
                                autofillHints: const [AutofillHints.username],
                                decoration: InputDecoration(
                                  labelText: l10n.webDavUsername,
                                  prefixIcon:
                                      const Icon(Icons.person_outline_rounded),
                                ),
                                onChanged: _invalidateTest,
                                validator: (value) =>
                                    (value?.trim().isNotEmpty ?? false)
                                        ? null
                                        : l10n.webDavErrorAuthentication,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: l10n.webDavPassword,
                                  helperText: hasStoredConfiguration
                                      ? l10n.webDavPasswordHint
                                      : null,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? l10n.settingsShow
                                        : l10n.settingsHide,
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                onChanged: _invalidateTest,
                                validator: (value) =>
                                    (value?.isNotEmpty ?? false) ||
                                            hasStoredConfiguration
                                        ? null
                                        : l10n.webDavErrorAuthentication,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _rootController,
                                decoration: InputDecoration(
                                  labelText: l10n.webDavRootPath,
                                  prefixIcon: const Icon(Icons.folder_outlined),
                                ),
                                onChanged: _invalidateTest,
                                validator: (value) =>
                                    (value?.trim().isNotEmpty ?? false)
                                        ? null
                                        : l10n.webDavErrorUnknown,
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: _testing ? null : _testConnection,
                                icon: _testing
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.wifi_tethering_rounded),
                                label: Text(
                                  _testing
                                      ? l10n.webDavTestingConnection
                                      : l10n.webDavTestConnection,
                                ),
                              ),
                              if (_connectionVerified ||
                                  _connectionError != null) ...[
                                const SizedBox(height: 14),
                                Semantics(
                                  liveRegion: true,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: (_connectionVerified
                                              ? Colors.green
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .error)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _connectionVerified
                                              ? Icons.check_circle_outline
                                              : Icons.error_outline,
                                          color: _connectionVerified
                                              ? Colors.green
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _connectionVerified
                                                ? l10n.webDavConnectionSuccess
                                                : webDavSyncErrorText(
                                                    context,
                                                    _connectionError,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SectionCard(
                          title: l10n.webDavSyncContent,
                          icon: Icons.sync_alt_rounded,
                          child: Column(
                            children: [
                              _ScopeSwitch(
                                title: l10n.webDavScopeBooks,
                                icon: Icons.library_books_outlined,
                                value: _scope.books,
                                onChanged: (value) => setState(
                                  () => _scope = _scope.copyWith(books: value),
                                ),
                              ),
                              _ScopeSwitch(
                                title: l10n.webDavScopeProgress,
                                icon: Icons.auto_stories_outlined,
                                value: _scope.progress,
                                onChanged: (value) => setState(
                                  () =>
                                      _scope = _scope.copyWith(progress: value),
                                ),
                              ),
                              _ScopeSwitch(
                                title: l10n.webDavScopeBookmarks,
                                icon: Icons.bookmark_border_rounded,
                                value: _scope.bookmarks,
                                onChanged: (value) => setState(
                                  () => _scope =
                                      _scope.copyWith(bookmarks: value),
                                ),
                              ),
                              _ScopeSwitch(
                                title: l10n.webDavScopeReadingSessions,
                                icon: Icons.bar_chart_rounded,
                                value: _scope.readingSessions,
                                onChanged: (value) => setState(
                                  () => _scope = _scope.copyWith(
                                    readingSessions: value,
                                  ),
                                ),
                              ),
                              _ScopeSwitch(
                                title: l10n.webDavScopeBookFiles,
                                subtitle: sync.fileCapabilities.uploadSupported
                                    ? l10n.webDavBookFilesHint
                                    : l10n.webDavBookFilesUnavailable,
                                icon: Icons.cloud_upload_outlined,
                                value: _scope.bookFiles &&
                                    sync.fileCapabilities.uploadSupported,
                                enabled: sync.fileCapabilities.uploadSupported,
                                onChanged: (value) => setState(
                                  () => _scope =
                                      _scope.copyWith(bookFiles: value),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: palette.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: palette.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.security_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(l10n.webDavSecurityNotice)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed:
                              _connectionVerified && !_saving ? _save : null,
                          child: Text(l10n.webDavSaveConfiguration),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = PageStyleHelper.palette(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 9),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
        Material(
          color: palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _ScopeSwitch extends StatelessWidget {
  const _ScopeSwitch({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}
