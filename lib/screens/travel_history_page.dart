import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class DriverTravelHistoryPage extends StatefulWidget {
  const DriverTravelHistoryPage({super.key});

  @override
  State<DriverTravelHistoryPage> createState() => _DriverTravelHistoryPageState();
}

class _DriverTravelHistoryPageState extends State<DriverTravelHistoryPage> {
  List<Map<String, dynamic>> _travels = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get('/api/travels/driver?pageSize=50');
      setState(() {
        _travels = (response.data['items'] as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Viagens'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF4E4E4E),
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
                        padding: const EdgeInsets.all(16),
                        itemCount: _travels.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (_, i) => ListTile(
                          leading: Icon(
                            _statusIcon(_travels[i]['status'] as String?),
                            color: _statusColor(_travels[i]['status'] as String?),
                          ),
                          title: Text(_travels[i]['passengerName'] as String? ?? 'Passageiro'),
                          subtitle: Text('Status: ${_travels[i]['status']}'),
                          trailing: Text(
                            _formatDate(_travels[i]['createdAt'] as String?),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF4E4E4E)),
                          ),
                        ),
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
      case 'Completed': return Colors.green;
      case 'Cancelled': return Colors.red;
      case 'InProgress': return const Color(0xFF4685C0);
      default: return Colors.orange;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
