import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:window_manager/window_manager.dart';
import '../l10n/app_localizations.dart';
import '../models/server_config.dart';
import '../services/dufs_service.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  final ServerConfig config;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<String> onColorChanged;

  const HomePage({
    super.key,
    required this.config,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onColorChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener {
  late ServerConfig _config;
  bool _showAdvanced = false;
  bool _enableAuth = false;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  int _navIndex = 0;

  AppLocalizations get l10n => AppLocalizations(_config.language);

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _config = widget.config;
    if (_config.auth != null && _config.auth!.contains(':')) {
      final parts = _config.auth!.split(':');
      _enableAuth = true;
      _usernameController.text = parts[0];
      _passwordController.text = parts.sublist(1).join(':');
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    if (_enableAuth) {
      final user = _usernameController.text.trim();
      final pass = _passwordController.text.trim();
      _config.auth = (user.isNotEmpty) ? '$user:$pass' : null;
    } else {
      _config.auth = null;
    }
    await _config.save();
  }

  Future<void> _pickDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() => _config.path = result);
      await _saveConfig();
    }
  }

  // ==================== Title Bar ====================

  Widget _buildTitleBar() {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 40,
        color: Colors.transparent,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.swap_horiz, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text('inout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
            const Spacer(),
            _TitleBarButton(icon: Icons.remove, onPressed: () => windowManager.minimize()),
            _TitleBarButton(icon: Icons.crop_square, onPressed: () async {
              if (await windowManager.isMaximized()) { windowManager.unmaximize(); } else { windowManager.maximize(); }
            }),
            _TitleBarButton(icon: Icons.close, isClose: true, onPressed: () => windowManager.close()),
          ],
        ),
      ),
    );
  }

  // ==================== Preset Dirs (Android) ====================

  Widget _buildPresetDirs() {
    if (Theme.of(context).platform != TargetPlatform.android) return const SizedBox.shrink();
    const presets = {
      'Download': '/storage/emulated/0/Download',
      'Documents': '/storage/emulated/0/Documents',
      'DCIM': '/storage/emulated/0/DCIM',
      'Movies': '/storage/emulated/0/Movies',
      'Music': '/storage/emulated/0/Music',
    };
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: presets.entries.map((e) {
        final sel = _config.path == e.value;
        return ActionChip(
          avatar: Icon(Icons.folder_outlined, size: 18,
              color: sel ? Theme.of(context).colorScheme.onPrimary : null),
          label: Text(e.key, style: TextStyle(color: sel ? Theme.of(context).colorScheme.onPrimary : null)),
          backgroundColor: sel ? Theme.of(context).colorScheme.primary : null,
          onPressed: () async { setState(() => _config.path = e.value); await _saveConfig(); },
        );
      }).toList(),
    );
  }

  // ==================== Dir Picker ====================

  Widget _buildDirPicker() {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickDirectory,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.folder_open, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.t('home.selectDir'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(_config.path.isEmpty ? l10n.t('home.selectDir') : _config.path,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _config.path.isEmpty ? Theme.of(context).colorScheme.outline : null),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }

  // ==================== Permission Presets ====================

  Widget _buildPermPresets(DufsService service) {
    final running = service.isRunning;
    return Row(children: [
      Expanded(child: FilterChip(
        avatar: const Icon(Icons.visibility, size: 18), label: Text(l10n.t('home.readonly')),
        selected: _config.readonly, showCheckmark: false,
        onSelected: running ? null : (_) async { setState(() => _config.applyReadonly()); await _saveConfig(); _maybeRestart(service); },
      )),
      const SizedBox(width: 8),
      Expanded(child: FilterChip(
        avatar: const Icon(Icons.cloud_upload, size: 18), label: Text(l10n.t('home.upload')),
        selected: !_config.readonly && _config.allowUpload && !_config.allowDelete, showCheckmark: false,
        onSelected: running ? null : (_) async { setState(() => _config.applyUpload()); await _saveConfig(); _maybeRestart(service); },
      )),
      const SizedBox(width: 8),
      Expanded(child: FilterChip(
        avatar: const Icon(Icons.lock_open, size: 18), label: Text(l10n.t('home.full')),
        selected: !_config.readonly && _config.allowUpload && _config.allowDelete, showCheckmark: false,
        onSelected: running ? null : (_) async { setState(() => _config.applyFull()); await _saveConfig(); _maybeRestart(service); },
      )),
    ]);
  }

  // ==================== Custom Permissions ====================

  Widget _buildCustomPerms(DufsService service) {
    final running = service.isRunning;
    final items = [
      {'label': l10n.t('home.allowUpload'), 'value': _config.allowUpload, 'icon': Icons.cloud_upload,
       'onChanged': (v) async { setState(() { _config.allowUpload = v; if (v) _config.readonly = false; }); await _saveConfig(); _maybeRestart(service); }},
      {'label': l10n.t('home.allowDelete'), 'value': _config.allowDelete, 'icon': Icons.delete_outline,
       'onChanged': (v) async { setState(() { _config.allowDelete = v; if (v) _config.readonly = false; }); await _saveConfig(); _maybeRestart(service); }},
      {'label': l10n.t('home.allowSearch'), 'value': _config.allowSearch, 'icon': Icons.search,
       'onChanged': (v) async { setState(() => _config.allowSearch = v); await _saveConfig(); _maybeRestart(service); }},
      {'label': l10n.t('home.allowArchive'), 'value': _config.allowArchive, 'icon': Icons.folder_zip,
       'onChanged': (v) async { setState(() => _config.allowArchive = v); await _saveConfig(); _maybeRestart(service); }},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ...items.map((item) {
            return SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              secondary: Icon(item['icon'] as IconData, size: 20,
                  color: running ? Theme.of(context).colorScheme.outline : null),
              title: Text(item['label'] as String),
              value: item['value'] as bool,
              onChanged: running ? null : (v) => (item['onChanged'] as Function(bool))(v),
            );
          }),
        ]),
      ),
    );
  }

  /// Auto-restart if running with no active connections
  Future<void> _maybeRestart(DufsService service) async {
    if (!service.isRunning) return;
    final hasConnections = service.totalRequests > 0 && service.lastActivity != null;
    if (hasConnections) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.t('perm.restartTitle')),
          content: Text(l10n.t('perm.restartMsg')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.t('perm.restart'))),
          ],
        ),
      );
      if (confirmed == true) await _restartServer(service);
    } else {
      await _restartServer(service);
    }
  }

  Future<void> _restartServer(DufsService service) async {
    await service.stopServer();
    await _saveConfig();
    await service.startServer(_config);
  }

  // ==================== Start/Stop Button ====================

  Widget _buildControlButton(DufsService service) {
    final running = service.isRunning;
    return SizedBox(
      width: double.infinity, height: 56,
      child: FilledButton.icon(
        icon: Icon(running ? Icons.stop : Icons.play_arrow),
        label: Text(running ? l10n.t('home.stopServer') : l10n.t('home.startServer'),
            style: const TextStyle(fontSize: 16)),
        style: FilledButton.styleFrom(
          backgroundColor: running ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () async {
          if (running) { await service.stopServer(); }
          else { await _saveConfig(); await service.startServer(_config); }
        },
      ),
    );
  }

  // ==================== Running Card (QR + Stats) ====================

  Widget _buildRunningCard(DufsService service) {
    if (!service.isRunning || service.serverUrl == null) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Status dot
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(l10n.t('home.running'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer)),
          ]),
          const SizedBox(height: 16),
          // QR Code
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: QrImageView(data: service.serverUrl!, version: QrVersions.auto, size: 180, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 12),
          // URL (tap to copy)
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: service.serverUrl!));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('home.copyUrl'))));
            },
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(child: Text(service.serverUrl!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      decoration: TextDecoration.underline),
                  overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 4),
              Icon(Icons.copy, size: 16, color: Theme.of(context).colorScheme.onPrimaryContainer),
            ]),
          ),
          const SizedBox(height: 8),
          // IP + Hint
          Text('${l10n.t('home.localIp')}: ${service.localIp ?? 'N/A'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7))),
          const SizedBox(height: 4),
          Text(l10n.t('home.scanHint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7))),
          const SizedBox(height: 12),
          // Stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _stat(context, Icons.http, '${service.totalRequests}', 'Requests'),
              Container(width: 1, height: 24, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
              _stat(context, Icons.access_time, service.lastActivity ?? '--', 'Last'),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _stat(BuildContext context, IconData icon, String value, String label) {
    return Column(children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7)),
      const SizedBox(height: 2),
      Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer)),
      Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.6))),
    ]);
  }

  // ==================== Error Banner ====================

  Widget _buildError(DufsService service) {
    if (service.error == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
        const SizedBox(width: 8),
        Expanded(child: Text(service.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer))),
      ]),
    );
  }

  // ==================== Advanced Options ====================

  Widget _buildAdvancedOptions() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(children: [
      // Port
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          decoration: InputDecoration(labelText: l10n.t('home.port'), prefixIcon: const Icon(Icons.numbers)),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          controller: TextEditingController(text: _config.port.toString()),
          onChanged: (v) async {
            final port = int.tryParse(v);
            if (port != null && port > 0 && port <= 65535) { _config.port = port; await _saveConfig(); }
          },
        ),
      ),
      const SizedBox(height: 8),
      // Auth
      SwitchListTile(
        title: Text(l10n.t('home.enableAuth')),
        value: _enableAuth,
        onChanged: (v) async { setState(() => _enableAuth = v); await _saveConfig(); },
      ),
      if (_enableAuth) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: l10n.t('home.username'), prefixIcon: const Icon(Icons.person)),
            onChanged: (_) => _saveConfig(),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _passwordController, obscureText: true,
            decoration: InputDecoration(labelText: l10n.t('home.password'), prefixIcon: const Icon(Icons.lock)),
            onChanged: (_) => _saveConfig(),
          ),
        ),
      ],
      // CORS
      SwitchListTile(
        title: Text(l10n.t('home.cors')),
        subtitle: Text(l10n.t('home.corsHint'), style: Theme.of(context).textTheme.bodySmall),
        value: _config.cors,
        onChanged: (v) async { setState(() => _config.cors = v); await _saveConfig(); },
      ),
      const SizedBox(height: 8),
    ]),
    );
  }

  // ==================== Main Content ====================

  Widget _buildHomeContent() {
    final service = context.watch<DufsService>();
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Title
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(children: [
            Text(l10n.t('app.name'),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            Text(l10n.t('app.slogan'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
          ]),
        ),
        // Preset dirs (Android)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildPresetDirs()),
        const SizedBox(height: 8),
        // Dir picker
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildDirPicker()),
        const SizedBox(height: 16),
        // Permission presets
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l10n.t('home.permissionPreset'), style: Theme.of(context).textTheme.titleSmall),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildPermPresets(service)),
        // Custom permissions (collapsible)
        ExpansionTile(
          title: Text(l10n.t('home.customPerm'), style: Theme.of(context).textTheme.titleSmall),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          initiallyExpanded: false,
          clipBehavior: Clip.hardEdge,
          children: [_buildCustomPerms(service)],
        ),
        const SizedBox(height: 16),
        // Error
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildError(service)),
        if (service.error != null) const SizedBox(height: 8),
        // Start/Stop
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildControlButton(service)),
        // Restart hint
        if (!service.isRunning)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 14, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 4),
                Text(l10n.t('home.restartHint'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        // Running card (QR) - appears between button and advanced
        _buildRunningCard(service),
        const SizedBox(height: 8),
        // Advanced options (always at bottom)
        ExpansionTile(
          title: Text(l10n.t('home.advanced')),
          initiallyExpanded: _showAdvanced,
          onExpansionChanged: (v) => setState(() => _showAdvanced = v),
          clipBehavior: Clip.hardEdge,
          children: [_buildAdvancedOptions()],
        ),
      ]),
    );
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomeContent(),
      SettingsPage(
        config: _config,
        onConfigChanged: _saveConfig,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
        onColorChanged: widget.onColorChanged,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          if (Theme.of(context).platform == TargetPlatform.windows) _buildTitleBar(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.03, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_navIndex),
                child: pages[_navIndex],
              ),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l10n.t('nav.home')),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: l10n.t('nav.settings')),
        ],
      ),
    );
  }
}

// Title bar button widget
class _TitleBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;
  const _TitleBarButton({required this.icon, required this.onPressed, this.isClose = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40, height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: isClose ? Colors.red.withValues(alpha: 0.8) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          child: Icon(icon, size: 16, color: isClose ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}
