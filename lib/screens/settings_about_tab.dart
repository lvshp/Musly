import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

class SettingsAboutTab extends StatefulWidget {
  const SettingsAboutTab({super.key});

  @override
  State<SettingsAboutTab> createState() => _SettingsAboutTabState();
}

class _SettingsAboutTabState extends State<SettingsAboutTab> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final version = await UpdateService.getCurrentVersion();
    if (!mounted) return;
    setState(() => _version = version);
  }

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        _buildSection(
          context,
          title: l10n.sectionAboutInformation,
          children: [
            _buildInfoTile(
              context,
              icon: CupertinoIcons.info,
              iconColor: Theme.of(context).colorScheme.primary,
              title: l10n.aboutVersion,
              subtitle: _version.isEmpty ? '...' : _version,
            ),
            _buildDivider(context),
            _buildInfoTile(
              context,
              icon: CupertinoIcons.device_phone_portrait,
              iconColor: const Color(0xFF007AFF),
              title: l10n.aboutPlatform,
              subtitle: Theme.of(context).platform.name.toUpperCase(),
            ),
            _buildDivider(context),
            _buildLinkTile(
              context,
              icon: Icons.code_rounded,
              title: l10n.aboutLinkGitHub,
              subtitle: UpdateService.repositoryUrl,
              url: UpdateService.repositoryUrl,
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: _isDark(context)
                  ? AppTheme.darkSecondaryText
                  : AppTheme.lightSecondaryText,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _isDark(context) ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Container(
        height: 0.5,
        color: _isDark(context) ? AppTheme.darkDivider : AppTheme.lightDivider,
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildIcon(context, icon: icon, iconColor: iconColor),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: Text(
        subtitle,
        style: TextStyle(
          fontSize: 16,
          color: _isDark(context)
              ? AppTheme.darkSecondaryText
              : AppTheme.lightSecondaryText,
        ),
      ),
    );
  }

  Widget _buildLinkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildIcon(
        context,
        icon: icon,
        iconColor: Theme.of(context).colorScheme.primary,
      ),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: _isDark(context)
              ? AppTheme.darkSecondaryText
              : AppTheme.lightSecondaryText,
        ),
      ),
      trailing: Icon(
        Icons.open_in_new_rounded,
        size: 18,
        color: _isDark(context)
            ? AppTheme.darkSecondaryText
            : AppTheme.lightSecondaryText,
      ),
      onTap: () => _openUrl(url),
    );
  }

  Widget _buildIcon(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: iconColor, size: 18),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error opening URL: $e');
    }
  }
}
