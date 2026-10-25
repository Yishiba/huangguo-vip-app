import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const HuangguoVIPApp());
}

class HuangguoVIPApp extends StatelessWidget {
  const HuangguoVIPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '黄果短剧 VIP版',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Map<String, dynamic>> _dramas = [];
  bool _loading = true;
  int _currentPage = 1;
  final int _totalPages = 144;
  String _filterStatus = 'all';
  String _filterSort = 'hot';
  bool _isVIP = true;

  final List<String> _apiBases = [
    'https://huangguoai.com',
    'https://ctb09.ir95e08v.cc',
  ];

  @override
  void initState() {
    super.initState();
    _loadVIPStatus();
    _loadDramas();
  }

  Future<void> _loadVIPStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isVIP = prefs.getBool('isVIP') ?? true;
    });
  }

  Future<void> _loadDramas() async {
    setState(() => _loading = true);

    for (final apiBase in _apiBases) {
      try {
        final params = <String, String>{
          'page': _currentPage.toString(),
          if (_filterSort == 'hot') 'sort': 'hot',
          if (_filterSort == 'new') 'sort': 'new',
          if (_filterStatus == 'completed') 'is_finished': '1',
          if (_filterStatus == 'unfinished') 'is_finished': '0',
        };

        final uri = Uri.parse('$apiBase/api/videos').replace(queryParameters: params);
        final response = await http.get(
          uri,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 1 && data['data'] != null) {
            final items = data['data']['items'] as List<dynamic>?;
            if (items != null) {
              setState(() {
                _dramas.clear();
                for (final item in items) {
                  _dramas.add({
                    'id': item['id'],
                    'title': item['title'] ?? '',
                    'cover': item['cover'] ?? '',
                    'score': (item['score'] ?? 0).toDouble(),
                    'episodes': item['episode_count'] ?? 1,
                    'isFinished': item['is_finished'] == true || item['is_finished'] == 1,
                    'tags': item['tags'] ?? [],
                    'desc': item['description'] ?? '',
                  });
                }
                _loading = false;
              });
              return;
            }
          }
        }
      } catch (e) {
        print('API error: $e');
        continue;
      }
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('黄果短剧'),
            if (_isVIP)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'VIP',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HistoryPage()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 3 / 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              padding: const EdgeInsets.all(8),
              itemCount: _dramas.length + (_currentPage < _totalPages ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _dramas.length) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _currentPage++;
                        });
                        _loadDramas();
                      },
                      child: const Text('加载更多'),
                    ),
                  );
                }
                final drama = _dramas[index];
                return DramaCard(
                  drama: drama,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailPage(dramaId: drama['id']),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('筛选条件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('状态'),
            Row(
              children: [
                FilterChip(
                  label: const Text('全部'),
                  selected: _filterStatus == 'all',
                  onSelected: (selected) {
                    setState(() => _filterStatus = 'all');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('已完结'),
                  selected: _filterStatus == 'completed',
                  onSelected: (selected) {
                    setState(() => _filterStatus = 'completed');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('连载中'),
                  selected: _filterStatus == 'unfinished',
                  onSelected: (selected) {
                    setState(() => _filterStatus = 'unfinished');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('排序'),
            Row(
              children: [
                FilterChip(
                  label: const Text('热门'),
                  selected: _filterSort == 'hot',
                  onSelected: (selected) {
                    setState(() => _filterSort = 'hot');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('最新'),
                  selected: _filterSort == 'new',
                  onSelected: (selected) {
                    setState(() => _filterSort = 'new');
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _currentPage = 1);
              _loadDramas();
              Navigator.pop(context);
            },
            child: const Text('应用'),
          ),
        ],
      ),
    );
  }
}

class DramaCard extends StatelessWidget {
  final Map<String, dynamic> drama;
  final VoidCallback onTap;

  const DramaCard({super.key, required this.drama, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Image.network(
                drama['cover'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[800],
                    child: const Center(child: Icon(Icons.error)),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drama['title'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          drama['score'].toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10, color: Colors.black),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        drama['isFinished'] ? '全${drama['episodes']}集' : '更新至${drama['episodes']}集',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailPage extends StatefulWidget {
  final int dramaId;

  const DetailPage({super.key, required this.dramaId});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  Map<String, dynamic>? _drama;
  List<int> _episodes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);

    try {
      final response = await http.get(
        Uri.parse('https://huangguoai.com/video/${widget.dramaId}/'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final html = response.body;
        final match = RegExp(r'<script[^>]*id="videoInitialData"[^>]*>(.*?)</script>')
            .firstMatch(html);
        if (match != null) {
          final jsonStr = match.group(1)!;
          final data = json.decode(jsonStr);
          final tracking = data['tracking'] as Map<String, dynamic>?;
          final totalEp = tracking?['total_episode'] ?? 1;
          final epPlaySrcs = data['epPlaySrcs'] as Map<String, dynamic>?;
          final availableEps = epPlaySrcs?.keys.length ?? 0;
          final isFinished = availableEps >= totalEp || data['is_finished'] == true;

          setState(() {
            _drama = {
              'id': widget.dramaId,
              'title': data['title'] ?? '',
              'cover': data['posterSrc'] ?? '',
              'desc': data['description'] ?? '',
              'tags': data['tags'] ?? [],
              'totalEpisodes': totalEp,
              'availableEpisodes': availableEps,
              'isFinished': isFinished,
              'epPlaySrcs': epPlaySrcs ?? {},
              'score': data['score'] ?? 0,
            };
            _episodes = (epPlaySrcs?.keys ?? [])
                .map((e) => int.parse(e.toString()))
                .toList()
              ..sort();
            _loading = false;
          });
        }
      }
    } catch (e) {
      print('Detail error: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_drama?['title'] ?? '加载中...'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _drama == null
              ? const Center(child: Text('加载失败'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.network(_drama!['cover']),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _drama!['title'],
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  _drama!['isFinished'] ? '已完结' : '连载中',
                                  style: const TextStyle(color: Colors.amber),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  _drama!['isFinished']
                                      ? '全${_drama!['totalEpisodes']}集'
                                      : '更新至${_drama!['availableEpisodes']}集',
                                ),
                                const SizedBox(width: 16),
                                Text('${_drama!['score']}分'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (_drama!['tags'] as List<dynamic>)
                                  .map((tag) => Chip(
                                        label: Text(tag.toString()),
                                        backgroundColor: Colors.amber.withOpacity(0.2),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                            Text(_drama!['desc']),
                            const SizedBox(height: 24),
                            const Text(
                              '剧集列表',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _episodes
                                  .map((ep) => ElevatedButton(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PlayerPage(
                                              dramaId: widget.dramaId,
                                              episode: ep,
                                              epPlaySrcs: _drama!['epPlaySrcs'],
                                              dramaTitle: _drama!['title'],
                                            ),
                                          ),
                                        ),
                                        child: Text('第$ep集'),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class PlayerPage extends StatefulWidget {
  final int dramaId;
  final int episode;
  final Map<String, dynamic> epPlaySrcs;
  final String dramaTitle;

  const PlayerPage({
    super.key,
    required this.dramaId,
    required this.episode,
    required this.epPlaySrcs,
    required this.dramaTitle,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? _controller;
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _startProgressTimer();
  }

  Future<void> _initPlayer() async {
    final videoUrl = widget.epPlaySrcs[widget.episode.toString()] as String?;
    if (videoUrl == null) {
      setState(() => _loading = false);
      return;
    }

    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await _controller!.initialize();
    await _controller!.play();

    // 恢复上次进度
    final prefs = await SharedPreferences.getInstance();
    final savedTime = prefs.getDouble('progress_${widget.dramaId}_${widget.episode}');
    if (savedTime != null && savedTime > 0) {
      _controller!.seekTo(Duration(seconds: savedTime.toInt()));
    }

    setState(() => _loading = false);
  }

  void _startProgressTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_controller != null && _controller!.value.isInitialized) {
        _saveProgress();
      }
    });
  }

  Future<void> _saveProgress() async {
    if (_controller != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
        'progress_${widget.dramaId}_${widget.episode}',
        _controller!.value.position.inSeconds.toDouble(),
      );
      await prefs.setInt('last_drama_id', widget.dramaId);
      await prefs.setInt('last_episode', widget.episode);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.dramaTitle} - 第${widget.episode}集'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
                VideoProgressIndicator(_controller!, allowScrubbing: true),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10),
                      onPressed: () => _controller!.seekTo(
                        _controller!.value.position - const Duration(seconds: 10),
                      ),
                    ),
                    IconButton(
                      icon: Icon(_controller!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: () {
                        setState(() {
                          _controller!.value.isPlaying
                              ? _controller!.pause()
                              : _controller!.play();
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_10),
                      onPressed: () => _controller!.seekTo(
                        _controller!.value.position + const Duration(seconds: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDramaId = prefs.getInt('last_drama_id');
    final lastEpisode = prefs.getInt('last_episode');

    if (lastDramaId != null && lastEpisode != null) {
      setState(() {
        _history = [
          {
            'dramaId': lastDramaId,
            'episode': lastEpisode,
          }
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('观看历史'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('last_drama_id');
              await prefs.remove('last_episode');
              setState(() => _history.clear());
            },
          ),
        ],
      ),
      body: _history.isEmpty
          ? const Center(child: Text('暂无观看历史'))
          : ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];
                return ListTile(
                  title: Text('短剧 ID: ${item['dramaId']}'),
                  subtitle: Text('第${item['episode']}集'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailPage(dramaId: item['dramaId']),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
