import 'dart:convert';

import 'package:http/http.dart' as http;

// ==========================================
// WEATHER DATA
// ==========================================

class WeatherData {
  final double temperature;
  final int weatherCode;
  final double precipitation;
  final double windSpeed;

  WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.precipitation,
    required this.windSpeed,
  });

  // ==========================================
  // WEATHER DESCRIPTION
  // ==========================================

  String get description {
    switch (weatherCode) {
      case 0:
        return "Clear Sky";

      case 1:
        return "Mainly Clear";

      case 2:
        return "Partly Cloudy";

      case 3:
        return "Overcast";

      case 45:
      case 48:
        return "Foggy";

      case 51:
        return "Light Drizzle";

      case 53:
        return "Drizzle";

      case 55:
        return "Heavy Drizzle";

      case 56:
      case 57:
        return "Freezing Drizzle";

      case 61:
        return "Light Rain";

      case 63:
        return "Moderate Rain";

      case 65:
        return "Heavy Rain";

      case 66:
      case 67:
        return "Freezing Rain";

      case 71:
      case 73:
      case 75:
        return "Snow";

      case 77:
        return "Snow Grains";

      case 80:
        return "Light Rain Showers";

      case 81:
        return "Moderate Rain Showers";

      case 82:
        return "Heavy Rain Showers";

      case 85:
      case 86:
        return "Snow Showers";

      case 95:
        return "Thunderstorm";

      case 96:
      case 99:
        return "Thunderstorm with Hail";

      default:
        return "Unknown Weather";
    }
  }

  // ==========================================
  // WEATHER EMOJI
  // ==========================================

  String get emoji {
    switch (weatherCode) {
      case 0:
        return "☀️";

      case 1:
        return "🌤️";

      case 2:
      case 3:
        return "⛅";

      case 45:
      case 48:
        return "🌫️";

      case 51:
      case 53:
      case 55:
        return "🌦️";

      case 56:
      case 57:
        return "🌧️";

      case 61:
        return "🌦️";

      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return "🌧️";

      case 66:
      case 67:
        return "🌧️";

      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return "❄️";

      case 95:
      case 96:
      case 99:
        return "⛈️";

      default:
        return "🌤️";
    }
  }

  // ==========================================
  // LIGHT RAIN CHECK
  // ==========================================

  bool get isLightRain {
    return weatherCode == 61;
  }

  // ==========================================
  // RAIN CHECK
  // ==========================================

  bool get isRaining {
    return weatherCode == 51 ||
        weatherCode == 53 ||
        weatherCode == 55 ||
        weatherCode == 61 ||
        weatherCode == 63 ||
        weatherCode == 65 ||
        weatherCode == 80 ||
        weatherCode == 81 ||
        weatherCode == 82;
  }

  // ==========================================
  // WEATHER DELIVERY SURCHARGE
  // ==========================================

  double get deliverySurcharge {
    if (isLightRain) {
      return 10;
    }

    return 0;
  }

  // ==========================================
  // DELIVERY FEE
  // ==========================================

  double get deliveryFee {
    const double normalDeliveryFee = 25;

    return normalDeliveryFee + deliverySurcharge;
  }

  // ==========================================
  // SURCHARGE DESCRIPTION
  // ==========================================

  String get surchargeDescription {
    if (isLightRain) {
      return "Light rain delivery charge";
    }

    return "";
  }
}

// ==========================================
// WEATHER SERVICE
// ==========================================

class WeatherService {
  // ==========================================
  // STORE / DELIVERY AREA LOCATION
  // ==========================================

  static const double latitude = 25.8438;
  static const double longitude = 93.4348;

  // ==========================================
  // GET CURRENT WEATHER
  // ==========================================

  Future<WeatherData> getCurrentWeather() async {
    final Uri url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&current=temperature_2m,weather_code,precipitation,wind_speed_10m'
      '&timezone=auto',
    );

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Unable to load weather. "
        "Error ${response.statusCode}",
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);

    final current = data['current'];

    if (current == null) {
      throw Exception("Weather information unavailable.");
    }

    return WeatherData(
      temperature: (current['temperature_2m'] as num).toDouble(),

      weatherCode: (current['weather_code'] as num).toInt(),

      precipitation: (current['precipitation'] as num).toDouble(),

      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
    );
  }
}
