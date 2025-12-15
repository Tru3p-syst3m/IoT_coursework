import 'dart:convert';
import 'package:dio/dio.dart';

class WeightData {
  final double weight;
  final String unit;
  final double timestamp;

  WeightData({
    required this.weight,
    required this.unit,
    required this.timestamp,
  });

  factory WeightData.fromJson(Map<String, dynamic> json) {
    return WeightData(
      weight: (json['weight'] as num).toDouble(),
      unit: json['unit'] ?? 'g',
      timestamp: (json['timestamp'] as num).toDouble(),
    );
  }
}

class ApiService {
  final Dio _dio = Dio();
  final String _baseUrl =
      'http://localhost:8000'; // Замените на ваш адрес сервера

  ApiService() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    // Добавляем логирование
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  Future<WeightData> getWeight() async {
    try {
      final response = await _dio.get('/api/get_weight');

      if (response.statusCode == 200) {
        return WeightData.fromJson(response.data);
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Таймаут подключения к серверу');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Таймаут получения данных');
      } else if (e.response != null) {
        throw Exception(
          'Ошибка ${e.response!.statusCode}: ${e.response!.data}',
        );
      } else {
        throw Exception('Ошибка сети: $e');
      }
    }
  }

  // Дополнительный метод для проверки соединения
  Future<bool> checkConnection() async {
    try {
      final response = await _dio.get(
        '/',
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
