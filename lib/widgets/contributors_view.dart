// 文件说明：展示 GitHub 仓库贡献者头像，并支持跳转到贡献者主页。
// 技术要点：GitHub REST API、Dio、响应式横向列表、URL Launcher。

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/page_style_helper.dart';
import 'side_toast.dart';

class ContributorsView extends StatefulWidget {
  final String repositoryOwner;
  final String repositoryName;

  const ContributorsView({
    super.key,
    required this.repositoryOwner,
    required this.repositoryName,
  });

  @override
  State<ContributorsView> createState() => _ContributorsViewState();
}

class _ContributorsViewState extends State<ContributorsView> {
  late final Dio _dio;
  late Future<List<_Contributor>> _contributorsFuture;

  bool get _isChinese =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';

  @override
  void initState() {
    super.initState();
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'open-reading-app',
        },
      ),
    );
    _contributorsFuture = _loadContributors();
  }

  @override
  void dispose() {
    _dio.close(force: true);
    super.dispose();
  }

  Future<List<_Contributor>> _loadContributors() async {
    final response = await _dio.get<List<dynamic>>(
      'https://api.github.com/repos/${widget.repositoryOwner}/'
      '${widget.repositoryName}/contributors',
      queryParameters: const {'per_page': 100},
    );
    final data = response.data ?? const <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(_Contributor.fromJson)
        .whereType<_Contributor>()
        .where((contributor) => !contributor.isBot)
        .toList(growable: false);
  }

  void _retry() {
    setState(() {
      _contributorsFuture = _loadContributors();
    });
  }

  Future<void> _openContributor(_Contributor contributor) async {
    final opened = await launchUrl(
      Uri.parse(contributor.profileUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      showSideToast(
        context,
        _isChinese ? '无法打开贡献者主页' : 'Could not open contributor profile',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = PageStyleHelper.palette(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.groups_2_outlined,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isChinese ? '贡献者' : 'Contributors',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isChinese
                          ? '感谢每一位让 Open Reading 变得更好的人'
                          : 'Thanks to everyone making Open Reading better',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<_Contributor>>(
            future: _contributorsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 78,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState(context);
              }

              final contributors = snapshot.data ?? const <_Contributor>[];
              if (contributors.isEmpty) {
                return SizedBox(
                  height: 60,
                  child: Center(
                    child: Text(
                      _isChinese
                          ? '暂时没有可展示的贡献者'
                          : 'No contributors to show yet',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                );
              }

              return SizedBox(
                height: 82,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: contributors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    return _buildContributor(contributors[index]);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContributor(_Contributor contributor) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: contributor.login,
      child: InkWell(
        onTap: () => _openContributor(contributor),
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 62,
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.24),
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: Image.network(
                    contributor.avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                contributor.login,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isChinese ? '贡献者加载失败，请检查网络后重试' : 'Could not load contributors',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: _retry,
            child: Text(_isChinese ? '重试' : 'Retry'),
          ),
        ],
      ),
    );
  }
}

class _Contributor {
  final String login;
  final String avatarUrl;
  final String profileUrl;
  final bool isBot;

  const _Contributor({
    required this.login,
    required this.avatarUrl,
    required this.profileUrl,
    required this.isBot,
  });

  static _Contributor? fromJson(Map<String, dynamic> json) {
    final login = json['login'] as String?;
    final avatarUrl = json['avatar_url'] as String?;
    final profileUrl = json['html_url'] as String?;
    if (login == null ||
        login.isEmpty ||
        avatarUrl == null ||
        avatarUrl.isEmpty ||
        profileUrl == null ||
        profileUrl.isEmpty) {
      return null;
    }
    final type = json['type'] as String?;
    return _Contributor(
      login: login,
      avatarUrl: avatarUrl,
      profileUrl: profileUrl,
      isBot: type == 'Bot' || login.endsWith('[bot]'),
    );
  }
}
