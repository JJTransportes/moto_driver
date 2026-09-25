import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/design_system/design_system.dart';

class DriverTravelHistoryPage extends StatefulWidget {
  const DriverTravelHistoryPage({super.key});

  @override
  State<DriverTravelHistoryPage> createState() => _DriverTravelHistoryPageState();
}

class _DriverTravelHistoryPageState extends State<DriverTravelHistoryPage> {
  static const int _pageSize = 20;

  final List<Map<String, dynamic>> _travels = [];
  final ScrollController _scrollController = ScrollController();

  int _page = 1;
  int? _totalCount;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

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

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
    });

    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get('/api/travels/driver?page=1&pageSize=$_pageSize');
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
      final response = await dio.get('/api/travels/driver?page=$nextPage&pageSize=$_pageSize');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Viagens'),
        foregroundColor: context.moto.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
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
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _travels.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: MotoSpace.s3),
                        itemBuilder: (_, i) {
                          if (i >= _travels.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }

                          final status = _travels[i]['status'] as String?;
                          return MotoEnter(
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
                                          _travels[i]['passengerName'] as String? ?? 'Passageiro',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        MotoStatusBadge.trip(_tripStatus(status)),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatDate(_travels[i]['createdAt'] as String?),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
