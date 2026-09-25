import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/design_system/design_system.dart';

class DriverTravelHistoryPage extends StatefulWidget {
  const DriverTravelHistoryPage({super.key});

  @override
  State<DriverTravelHistoryPage> createState() => _DriverTravelHistoryPageState();
}

enum _HistoryFilter { todas, concluidas, canceladas }

class _DriverTravelHistoryPageState extends State<DriverTravelHistoryPage> {
  static const int _pageSize = 20;

  final List<Map<String, dynamic>> _travels = [];
  final ScrollController _scrollController = ScrollController();

  int _page = 1;
  int? _totalCount;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  _HistoryFilter _filter = _HistoryFilter.todas;

  List<String>? get _statusQuery => switch (_filter) {
        _HistoryFilter.todas => null,
        _HistoryFilter.concluidas => const ['Completed'],
        _HistoryFilter.canceladas => const ['Cancelled'],
      };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadHistory();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  bool get _hasMore => _totalCount == null || _travels.length < _totalCount!;

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Map<String, dynamic> _queryParams(int page) {
    final params = <String, dynamic>{'page': page, 'pageSize': _pageSize};
    final status = _statusQuery;
    if (status != null) params['status'] = status;
    return params;
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
    });

    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get('/api/travels/driver', queryParameters: _queryParams(1));
      final items = (response.data['items'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _travels
          ..clear()
          ..addAll(items);
        _totalCount = response.data['totalCount'] as int?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);

    try {
      final dio = Modular.get<Dio>();
      final nextPage = _page + 1;
      final response = await dio.get('/api/travels/driver', queryParameters: _queryParams(nextPage));
      final items = (response.data['items'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _travels.addAll(items);
        _totalCount = response.data['totalCount'] as int?;
        _page = nextPage;
        _isLoadingMore = false;
      });
    } catch (_) {
      // Falha ao buscar a próxima página não deve derrubar a lista já
      // carregada — só permite que o usuário tente rolar novamente.
      setState(() => _isLoadingMore = false);
    }
  }

  void _onFilterChanged(_HistoryFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = _buildDisplayItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        foregroundColor: context.moto.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<_HistoryFilter>(
              segments: const [
                ButtonSegment(value: _HistoryFilter.todas, label: Text('Todas')),
                ButtonSegment(value: _HistoryFilter.concluidas, label: Text('Concluídas')),
                ButtonSegment(value: _HistoryFilter.canceladas, label: Text('Canceladas')),
              ],
              selected: {_filter},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _onFilterChanged(s.first),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Erro ao carregar: $_error'),
                            const SizedBox(height: 16),
                            MotoButton(label: 'Tentar novamente', large: false, expand: false, onPressed: _loadHistory),
                          ],
                        ),
                      )
                    : _travels.isEmpty
                        ? const Center(child: Text('Nenhuma viagem encontrada'))
                        : RefreshIndicator(
                            onRefresh: _loadHistory,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: displayItems.length + (_hasMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i >= displayItems.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                }

                                final item = displayItems[i];
                                if (item is String) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(4, MotoSpace.s4, 4, MotoSpace.s2),
                                    child: Text(
                                      item,
                                      style: TextStyle(
                                        fontFamily: MotoFont.ui,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        color: context.moto.textTertiary,
                                      ),
                                    ),
                                  );
                                }

                                final travel = item as Map<String, dynamic>;
                                final status = travel['status'] as String?;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: MotoSpace.s3),
                                  child: MotoEnter(
                                    index: i,
                                    child: MotoGlass(
                                      painted: true,
                                      padding: const EdgeInsets.all(MotoSpace.s4),
                                      child: Row(
                                        children: [
                                          MotoTile(icon: _statusIcon(status), tone: _statusTone(status)),
                                          const SizedBox(width: MotoSpace.s3),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  travel['passengerName'] as String? ?? 'Passageiro',
                                                  style: Theme.of(context).textTheme.titleMedium,
                                                ),
                                                const SizedBox(height: 4),
                                                MotoStatusBadge.trip(_tripStatus(status)),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            _formatTime(travel['createdAt'] as String?),
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  /// Mistura cabeçalhos de data ("HOJE · 18 SET") com as viagens, na ordem
  /// em que já chegam da API (mais recentes primeiro).
  List<Object> _buildDisplayItems() {
    final items = <Object>[];
    String? lastDayLabel;
    for (final travel in _travels) {
      final dt = DateTime.tryParse(travel['createdAt'] as String? ?? '')?.toLocal();
      final label = dt == null ? '' : _dayLabel(dt);
      if (label != lastDayLabel) {
        items.add(label);
        lastDayLabel = label;
      }
      items.add(travel);
    }
    return items;
  }

  static const _months = [
    'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ',
  ];

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(that).inDays;
    final dateSuffix = '${dt.day} ${_months[dt.month - 1]}';
    if (diff == 0) return 'HOJE · $dateSuffix';
    if (diff == 1) return 'ONTEM · $dateSuffix';
    return dateSuffix;
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr)?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'Completed': return Icons.task_alt;
      case 'Cancelled': return Icons.cancel;
      case 'InProgress': return Icons.directions_car;
      default: return Icons.access_time;
    }
  }

  MotoTone _statusTone(String? status) {
    switch (status) {
      case 'Completed': return MotoTone.success;
      case 'Cancelled': return MotoTone.danger;
      case 'InProgress': return MotoTone.info;
      default: return MotoTone.warning;
    }
  }

  TripStatus _tripStatus(String? status) {
    switch (status) {
      case 'Completed': return TripStatus.concluida;
      case 'Cancelled': return TripStatus.cancelada;
      case 'InProgress': return TripStatus.emAndamento;
      case 'Accepted': return TripStatus.aceita;
      default: return TripStatus.solicitada;
    }
  }

}
