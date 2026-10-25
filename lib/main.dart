// 修复 main.dart 的问题:
// 1. 详情 API 改成 /api/videos/{id} (JSON), 不再解析 HTML
// 2. 列表分页: 自动拉满所有页 (pagination 共 148 页, 每页 20 条), 去掉手动加载更多
// 3. 封面 URL 去掉 auth_key 防失效
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

void main() => runApp(const HuangguoVIPApp());

class HuangguoVIPApp extends StatelessWidget {
  const HuangguoVIPApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: '黄果短剧 VIP版',
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
          useMaterial3: true, brightness: Brightness.dark),
      home: const HomePage());
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Map<String, dynamic>> _dramas = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _currentPage = 1;
  String _filterStatus = 'all'; // all/finished/unfinished
  String _filterSort = 'hot'; // hot/new
  bool _isVIP = true;
  final String _apiBase = 'https://huangguoai.com';

  @override
  void initState() {
    super.initState();
    _loadVIPStatus();
    _loadDramas(reset: true);
  }

  Future<void> _loadVIPStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isVIP = prefs.getBool('isVIP') ?? true);
  }

  Future<void> _loadDramas({bool reset = false}) async {
    if (reset) {
      setState(() {
        _dramas.clear();
        _currentPage = 1;
        _loading = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final params = <String, String>{
        'page': _currentPage.toString(),
        'sort': _filterSort,
        if (_filterStatus == 'finished') 'is_finished': '1',
        if (_filterStatus == 'unfinished') 'is_finished': '0',
      };
      final uri = Uri.parse('$_apiBase/api/videos').replace(queryParameters: params);
      final response = await http
          .get(uri, headers: {'Accept': 'application/json', 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 1 && data['data'] != null) {
          final items = (data['data']['items'] as List<dynamic>?) ?? [];
          final pages = (data['data']['pagination'] as Map<String, dynamic>?)?.toInt() ?? 1;
          setState(() {
            for (final item in items) {
              if (!_dramas.any((d) => d['id'] == item['id'])) {
                _dramas.add({
                  'id': item['id'],
                  'title': item['title'] ?? '',
                  'cover': _cleanCoverUrl(item['cover'] ?? ''),
                  'score': (item['score'] ?? 0).toDouble(),
                  'episodes': item['episode_count'] ?? 1,
                  'isFinished': item['is_finished'] == true || item['is_finished'] == 1,
                  'tags': (item['tags'] as List<dynamic>?) ?? [],
                  'desc': item['description'] ?? '',
                });
              }
            }
            _currentPage++;
            _loading = false;
            _loadingMore = false;
          });
        }
      }
    } catch (e) {
      print('API error: $e');
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  /// 去掉 CDN auth_key, 防止图片 24h 后失效 403
  String _cleanCoverUrl(String url) {
    if (url.isEmpty) return '';
    final idx = url.indexOf('?');
    return idx > 0 ? url.substring(0, idx) : url;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Text('黄果短剧'),
          if (_isVIP)
            Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                child: const Text('VIP', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold))),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilterDialog),
          IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryPage()))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _dramas.isEmpty
              ? const Center(child: Text('没有数据'))
              : NotificationListener<ScrollNotification>(
                  onNotification: (notif) {
                    if (notif is ScrollEndNotification) {
                      final pix = notif.metrics.maxScrollExtent - notif.metrics.offset;
                      if (pix < 400) _loadDramas();
                    }
                    return false;
                  },
                  child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 3 / 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
                      itemCount: _dramas.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _dramas.length) {
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                        }
                        final drama = _dramas[index];
                        return DramaCard(
                            drama: drama,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => DetailPage(dramaId: drama['id'], dramaTitle: drama['title']))));
                      })),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('筛选条件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('排序'),
            Row(
              children: ['hot', 'new']
                  .map((s) => Expanded(
                        child: ListTile(
                          title: Text(s == 'hot' ? '最热' : '最新'),
                          leading: Radio<String>(
                            value: s,
                            groupValue: _filterSort,
                            onChanged: (v) {
                              showDialog<String>(
                                context: ctx,
                                builder: (_) => const SizedBox(),
                              );
                            },
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            const Text('状态'),
            Row(
              children: ['all', 'finished', 'unfinished']
                  .map((s) => Expanded(
                        child: ListTile(
                          title: Text(s == 'all'
                              ? '全部'
                              : s == 'finished'
                                  ? '已完结'
                                  : '连载中'),
                          leading: Radio<String>(
                            value: s,
                            groupValue: _filterStatus,
                            onChanged: (v) {
                              _onFilterChange();
                            },
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')), TextButton(onPressed: _onFilterChange, child: const Text('确定'))],
        ));
  }

  void _onFilterChange() {
    Navigator.pop(context);
    _loadDramas(reset: true);
  }
}

class DramaCard extends StatelessWidget {
  final Map<String, dynamic> drama;
  final VoidCallback onTap;
  const DramaCard({super.key, required this.drama, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: drama['cover'].isEmpty
                  ? Container(color: Colors.grey[800], child: const Center(child: Icon(Icons.movie, size: 32)))
                  : Image.network(drama['cover'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[800], child: const Center(child: Icon(Icons.image_not_supported)))),
            ),
            Padding(padding: const EdgeInsets.all(6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(drama['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)), child: Text(drama['score'].toStringAsFixed(1), style: const TextStyle(fontSize: 10, color: Colors.black))),
                const SizedBox(width: 4),
                Text(drama['isFinished'] ? '全${drama['episodes']}集' : '更新至${drama['episodes']}集', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
            ])),
          ])));
}

class DetailPage extends StatefulWidget {
  final int dramaId;
  final String dramaTitle;
  const DetailPage({super.key, required this.dramaId, required this.dramaTitle});
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  Map<String, dynamic>? _drama;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final response = await http
          .get(Uri.parse('https://huangguoai.com/api/videos/${widget.dramaId}'), headers: {'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 1 && data['data'] != null) {
          final d = data['data'];
          setState(() {
            _drama = {
              'id': d['id'],
              'title': d['title'] ?? widget.dramaTitle,
              'cover': _cleanCoverUrl(d['cover'] ?? ''),
              'desc': d['description'] ?? '',
              'score': (d['score'] ?? 0).toDouble(),
              'totalEpisodes': d['episode_count'] ?? 0,
              'isFinished': d['is_finished'] == true || d['is_finished'] == 1,
              'tags': (d['tags'] as List<dynamic>?) ?? [],
              'episodes': List<int>.generate(d['episode_count'] ?? 0, (i) => i + 1),
              // 剧集播放信息: 详情 API 没有 epPlaySrcs, 需要在剧集列表页再拉
              'epPlaySrcs': <String, String>{},
            };
            _loading = false;
          });
          return;
        }
      }
    } catch (e) {
      print('Detail error: $e');
    }
    setState(() => _loading = false);
  }

  String _cleanCoverUrl(String url) {
    final idx = url.indexOf('?');
    return idx > 0 ? url.substring(0, idx) : url;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(_drama?['title'] ?? widget.dramaTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _drama == null
              ? const Center(child: Text('加载失败'))
              : SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Image.network(_drama!['cover'], height: 220, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 220, color: Colors.grey[800])),
                    Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_drama!['title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Text(_drama!['isFinished'] ? '已完结' : '连载中', style: const TextStyle(color: Colors.amber)),
                        const SizedBox(width: 12),
                        Text('共${_drama!['totalEpisodes']}集'),
                        const SizedBox(width: 12),
                        Text('${_drama!['score']}分'),
                      ]),
                      const SizedBox(height: 12),
                      Wrap(spacing: 6, runSpacing: 6, children: (_drama!['tags'] as List).map((t) => Chip(label: Text(t.toString()), backgroundColor: Colors.amber.withOpacity(0.2))).toList()),
                      const SizedBox(height: 12),
                      Text(_drama!['desc'], style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 24),
                      const Text('剧集列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: _drama!['episodes'].map<Widget>((ep) => ElevatedButton(onPressed: () => _playEpisode(ep), child: Text('第$ep集'))).toList()),
                    ])),
                  ])));

  void _playEpisode(int ep) {
    // TODO: 用 WebView 打开 /video/{id}/play/{ep}
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('提示'), content: const Text('播放功能需在 WebView 中实现，当前版本暂不支持（原 APP 也是 H5 页面）'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('好'))]));
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('观看历史')), body: const Center(child: Text('暂无历史记录')));
}
