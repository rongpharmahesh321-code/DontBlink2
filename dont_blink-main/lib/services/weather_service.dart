import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// ==========================================================
// WEATHER DATA
// ==========================================================

class WeatherData {
  final double temperature;
  final double feelsLikeTemperature;
  final int humidity;
  final bool isDaytime;
  final String weatherType;
  final String weatherDescription;
  final double precipitation;
  final double rain;
  final double showers;
  final double windSpeed;
  final int precipitationProbability;

  WeatherData({
    required this.temperature,
    this.feelsLikeTemperature = 0,
    this.humidity = 0,
    this.isDaytime = true,
    required this.weatherType,
    required this.weatherDescription,
    required this.precipitation,
    required this.rain,
    required this.showers,
    required this.windSpeed,
    required this.precipitationProbability,
  });

  String get description {
    if (weatherDescription.trim().isNotEmpty) {
      return weatherDescription.trim();
    }

    final type = weatherType.toUpperCase();
    switch (type) {
      case 'CLEAR':
        return isDaytime ? 'Sunny' : 'Clear';
      case 'MOSTLY_CLEAR':
        return isDaytime ? 'Mostly sunny' : 'Mostly clear';
      case 'PARTLY_CLOUDY':
        return 'Partly cloudy';
      case 'MOSTLY_CLOUDY':
        return 'Mostly cloudy';
      case 'CLOUDY':
      case 'OVERCAST':
        return 'Cloudy';
      case 'FOG':
        return 'Foggy';
      case 'HAZE':
        return 'Hazy';
      case 'MIST':
        return 'Misty';
      case 'WINDY':
      case 'BREEZY':
        return 'Windy';
      case 'LIGHT_DRIZZLE':
      case 'DRIZZLE':
        return 'Light drizzle';
      case 'HEAVY_DRIZZLE':
        return 'Drizzle';
      case 'LIGHT_RAIN':
        return 'Light rain';
      case 'RAIN':
        return 'Rain';
      case 'HEAVY_RAIN':
        return 'Heavy rain';
      case 'LIGHT_RAIN_SHOWERS':
      case 'LIGHT_SHOWERS':
        return 'Light rain showers';
      case 'RAIN_SHOWERS':
      case 'SHOWERS':
        return 'Rain showers';
      case 'HEAVY_RAIN_SHOWERS':
      case 'HEAVY_SHOWERS':
        return 'Heavy rain showers';
      case 'THUNDERSTORM':
      case 'HEAVY_THUNDERSTORM':
      case 'THUNDERSHOWER':
        return 'Thunderstorm';
      case 'SNOW':
      case 'LIGHT_SNOW':
      case 'HEAVY_SNOW':
      case 'SNOW_SHOWERS':
        return 'Snow';
      default:
        return 'Clear';
    }
  }

  String get emoji {
    final type = weatherType.toUpperCase();

    if (isThunderstorm) return '⛈️';
    if (type.contains('HEAVY_RAIN') || type.contains('HEAVY_RAIN_SHOWERS')) {
      return '🌧️';
    }
    if (isRaining) {
      return isDaytime ? '🌦️' : '🌧️';
    }
    if (type.contains('SNOW') ||
        type.contains('ICE') ||
        type.contains('FLURRIES')) {
      return '❄️';
    }
    if (type.contains('FOG') ||
        type.contains('HAZE') ||
        type.contains('MIST') ||
        type.contains('SMOKE') ||
        type.contains('DUST')) {
      return '🌫️';
    }
    if (type.contains('WIND')) return '💨';
    if (type == 'CLOUDY' || type == 'OVERCAST' || type == 'MOSTLY_CLOUDY') {
      return '☁️';
    }
    if (type.contains('CLOUD')) {
      return isDaytime ? '⛅' : '☁️';
    }
    return isDaytime ? '☀️' : '🌙';
  }

  bool get isRaining {
    final type = weatherType.toUpperCase();

    // Condition type explicitly specifies rain/drizzle/showers/storms
    return type.contains('RAIN') ||
        type.contains('DRIZZLE') ||
        type.contains('SHOWER') ||
        type.contains('THUNDERSTORM') ||
        type.contains('THUNDERSHOWER');
  }

  bool get isThunderstorm {
    final type = weatherType.toUpperCase();

    return type.contains('THUNDERSTORM') || type.contains('THUNDERSHOWER');
  }

  double get deliverySurcharge {
    if (isThunderstorm) return 20;
    if (isRaining) return 10;
    return 0;
  }

  double get deliveryFee {
    const double normalDeliveryFee = 25;
    return normalDeliveryFee + deliverySurcharge;
  }

  String get surchargeDescription {
    if (isThunderstorm) return 'Severe weather delivery charge';
    if (isRaining) return 'Rain delivery charge';
    return '';
  }
}

// ==========================================================
// WEATHER SERVICE
// ==========================================================

class WeatherService {
  static const MethodChannel _channel = MethodChannel(
    'com.doorstepp.app/google_config',
  );

  static const String _defaultGoogleApiKey =
      'AIzaSyAAfhEQXi71C2sEtiynHLm8PnJROwn_gz4';

  Future<String> _getApiKey() async {
    try {
      final key = await _channel.invokeMethod<String>('getGoogleWebApiKey');

      if (key != null && key.trim().isNotEmpty) {
        return key.trim();
      }
    } on PlatformException catch (_) {
      // Platform channel unavailable; fall back to configured key
    } catch (_) {}

    return _defaultGoogleApiKey;
  }

  Future<WeatherData> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    final apiKey = await _getApiKey();

    final Uri url =
        Uri.https('weather.googleapis.com', '/v1/currentConditions:lookup', {
          'key': apiKey,
          'location.latitude': latitude.toString(),
          'location.longitude': longitude.toString(),
          'unitsSystem': 'METRIC',
        });

    final response = await http
        .get(url, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      String details = '';

      try {
        final errorData = jsonDecode(response.body);

        if (errorData is Map<String, dynamic>) {
          final error = errorData['error'];

          if (error is Map<String, dynamic>) {
            details = error['message']?.toString() ?? '';
          }
        }
      } catch (_) {}

      throw Exception(
        details.isNotEmpty
            ? 'Unable to load Google weather: $details'
            : 'Unable to load Google weather. Error ${response.statusCode}.',
      );
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid weather information received.');
    }

    final weatherCondition =
        decoded['weatherCondition'] as Map<String, dynamic>?;

    if (weatherCondition == null) {
      throw Exception('Weather condition unavailable.');
    }

    final type = weatherCondition['type']?.toString().toUpperCase() ?? '';

    String description = '';
    final descriptionMap =
        weatherCondition['description'] as Map<String, dynamic>?;

    if (descriptionMap != null) {
      description = descriptionMap['text']?.toString() ?? '';
    }

    double temperature = 0.0;
    final temperatureMap = decoded['temperature'] as Map<String, dynamic>?;

    if (temperatureMap != null) {
      temperature = (temperatureMap['degrees'] as num?)?.toDouble() ?? 0.0;
    }

    double feelsLike = temperature;
    final feelsLikeMap = (decoded['feelsLikeTemperature'] ??
        decoded['heatIndex'] ??
        decoded['windChill']) as Map<String, dynamic>?;

    if (feelsLikeMap != null) {
      feelsLike =
          (feelsLikeMap['degrees'] as num?)?.toDouble() ?? temperature;
    }

    final int humidity = (decoded['relativeHumidity'] as num?)?.toInt() ?? 0;
    final bool isDaytime = decoded['isDaytime'] as bool? ?? true;

    int precipitationProbability = 0;
    double precipitation = 0.0;

    final precipitationMap =
        decoded['precipitation'] as Map<String, dynamic>?;

    if (precipitationMap != null) {
      final probability = precipitationMap['probability'];

      if (probability is Map<String, dynamic>) {
        precipitationProbability =
            (probability['percent'] as num?)?.toInt() ?? 0;
      }

      final qpf = precipitationMap['qpf'];

      if (qpf is Map<String, dynamic>) {
        precipitation = (qpf['quantity'] as num?)?.toDouble() ?? 0.0;
      }
    }

    double windSpeed = 0.0;
    final windMap = decoded['wind'] as Map<String, dynamic>?;

    if (windMap != null) {
      final speed = windMap['speed'];

      if (speed is Map<String, dynamic>) {
        windSpeed = (speed['value'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return WeatherData(
      temperature: temperature,
      feelsLikeTemperature: feelsLike,
      humidity: humidity,
      isDaytime: isDaytime,
      weatherType: type,
      weatherDescription: description,
      precipitation: precipitation,
      rain: 0,
      showers: 0,
      windSpeed: windSpeed,
      precipitationProbability: precipitationProbability,
    );
  }
}
