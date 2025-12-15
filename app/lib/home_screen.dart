import 'package:flutter/material.dart';
import 'api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _limitController = TextEditingController(text: '100');
  double? _currentWeight;
  double? _setLimit;
  bool _isLoading = false;
  String _statusMessage = 'Нажмите "Получить вес" или задайте лимит';
  Color _statusColor = Colors.grey;
  final double _tolerance = 2.0; // Погрешность 2 грамма

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _setLimit = double.tryParse(_limitController.text);
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeight() async {
    if (_setLimit == null) {
      _showError('Введите корректный лимит');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final weightData = await _apiService.getWeight();

      setState(() {
        _currentWeight = weightData.weight;
        _updateStatus(_currentWeight!);
      });
    } catch (e) {
      _showError('Ошибка: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateStatus(double weight) {
    if (_setLimit == null) return;

    final difference = weight - _setLimit!;

    if (weight > _setLimit!) {
      // Перевес
      _statusMessage =
          'ПЕРЕВЕС! Превышение на ${difference.abs().toStringAsFixed(2)} г';
      _statusColor = Colors.red;
    } else if (weight < (_setLimit! - _tolerance)) {
      // Недостаточный вес
      _statusMessage =
          'СЛИШКОМ МАЛО! Не хватает ${difference.abs().toStringAsFixed(2)} г';
      _statusColor = Colors.blue;
    } else {
      // В пределах погрешности
      _statusMessage =
          'ВСЕ ХОРОШО! Вес в пределах погрешности (±$_tolerance г)';
      _statusColor = Colors.green;
    }
  }

  void _setNewLimit() {
    final limit = double.tryParse(_limitController.text);

    if (limit == null || limit <= 0) {
      _showError('Введите корректный лимит (положительное число)');
      return;
    }

    setState(() {
      _setLimit = limit;
      _statusMessage = 'Лимит установлен: $limit г';
      _statusColor = Colors.blueGrey;
    });

    // Если уже есть текущий вес, обновляем статус
    if (_currentWeight != null) {
      _updateStatus(_currentWeight!);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Монитор весов'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Поле для установки лимита
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Установить лимит веса',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _limitController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Лимит (граммы)',
                              border: OutlineInputBorder(),
                              suffixText: 'г',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _setNewLimit,
                          icon: const Icon(Icons.save),
                          label: const Text('Задать'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Текущий лимит
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Текущий лимит',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _setLimit != null
                          ? '${_setLimit!.toStringAsFixed(2)} г'
                          : 'Не установлен',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Кнопка получения веса
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchWeight,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.scale),
              label: Text(
                _isLoading ? 'Получение веса...' : 'Получить вес',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 30),

            // Отображение текущего веса
            if (_currentWeight != null)
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Текущий вес',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_currentWeight!.toStringAsFixed(2)} г',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Лимит: ${_setLimit!.toStringAsFixed(2)} г',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Статусная плашка
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _statusColor, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Легенда цветов
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Легенда:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(Colors.green, 'Норма (±$_tolerance г)'),
                    _buildLegendItem(Colors.blue, 'Недостаточный вес'),
                    _buildLegendItem(Colors.red, 'Перевес'),
                  ],
                ),
              ),
            ),

            // Спейсер внизу
            const Expanded(child: SizedBox()),

            // Информация о системе
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Погрешность измерения: ±2.0 г',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
