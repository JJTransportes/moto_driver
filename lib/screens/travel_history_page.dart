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
                      ElevatedButton(onPressed: _loadHistory, child: const Text('Tentar novamente')),
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
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (_, i) {
                          if (i >= _travels.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }

                          return ListTile(
                            leading: Icon(
                              _statusIcon(_travels[i]['status'] as String?),
                              color: _statusColor(_travels[i]['status'] as String?),
                            ),
                            title: Text(_travels[i]['passengerName'] as String? ?? 'Passageiro'),
                            subtitle: Text('Status: ${_statusLabel(_travels[i]['status'] as String?)}'),
                            trailing: Text(
                              _formatDate(_travels[i]['createdAt'] as String?),
                              style: TextStyle(fontSize: 12, color: context.moto.textPrimary),
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

  Color _statusColor(String? status) {
    switch (status) {
      case 'Completed': return context.moto.success;
      case 'Cancelled': return context.moto.danger;
      case 'InProgress': return context.moto.accent;
      default: return context.moto.warning;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'Completed': return 'Concluída';
      case 'Cancelled': return 'Cancelada';
      case 'InProgress': return 'Em andamento';
      case 'Accepted': return 'Aceita';
      case 'Pending': return 'Pendente';
      default: return status ?? '';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
