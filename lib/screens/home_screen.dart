import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../engine/speaker.dart';
import '../models/settings.dart';
import 'combination_screen.dart';
import 'meet_call_screen.dart';

/// 홈: 미트 콜, 콤보 카드 맵, 콤비네이션 보기.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.speaker});

  final Speaker speaker;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 콤보 카드 맵과 콤비네이션 보기는 미트 콜에서 고른 난이도·스탠스·콜 방식으로 연다.
  Future<TrainingSettings> _settings() => SettingsStore.load();

  Future<void> _openMeetCall() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => MeetCallScreen(speaker: widget.speaker)));

  Future<void> _openCombinations() async {
    final s = await _settings();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CombinationListScreen(settings: s)));
  }

  /// 콤보 카드 맵 (web/combo_map/, GitHub Pages에 웹 버전과 함께 배포).
  Future<void> _openComboMap() async {
    final s = await _settings();
    final query = 'stance=${s.stance.name}&level=${s.level.name}';
    // 웹은 앱과 같은 사이트라 같은 탭에서 이동하고(페이지의 "← 홈"으로 돌아옴), 폰 앱은 브라우저로 연다.
    final uri = kIsWeb ? Uri.base.resolve('combo_map/?$query') : Uri.parse('$_webAppUrl/combo_map/?$query');
    final ok = await launchUrl(uri, webOnlyWindowName: '_self');
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('콤보 카드 맵을 열지 못했어요')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('복싱 코치')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _MenuCard(
            icon: Icons.sports_mma,
            title: '미트 콜',
            body: '라운드 동안 콤보를 불러 줍니다. 난이도와 스탠스, 콜 방식을 고르고 시작하세요.',
            onTap: _openMeetCall,
          ),
          _MenuCard(
            icon: Icons.style,
            title: '콤보 카드 맵',
            body: '자세(체중)마다 다음에 이어질 수 있는 동작을 카드로 봅니다. 카드를 골라 콤보를 직접 만들어 볼 수 있어요.',
            onTap: _openComboMap,
          ),
          _MenuCard(
            icon: Icons.people_alt_outlined,
            title: '콤비네이션 보기',
            body: '난이도별 콤비네이션을 골라, 상대가 있을 때 어떻게 쓰이는지 두 인형의 시연으로 봅니다.',
            onTap: _openCombinations,
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.icon, required this.title, required this.body, required this.onTap});

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 40, color: scheme.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(body, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// 웹 버전 주소 (README 참고).
const _webAppUrl = 'https://a1216843.github.io/boxing';
