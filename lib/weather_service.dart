import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // Open-Meteo — no API key needed

  /// Fetch weather by city name (geocode first, then fetch)
  Future<Map<String, dynamic>> getWeather(String cityName) async {
    final clean = cityName.split(',')[0].trim();
    final encoded = Uri.encodeComponent(clean);
    final geoUrl = 'https://geocoding-api.open-meteo.com/v1/search?name=$encoded&count=1&language=en&format=json';
    
    final geoRes = await http.get(Uri.parse(geoUrl));
    if (geoRes.statusCode != 200) throw Exception('Geocoding failed');

    final geoData = json.decode(geoRes.body);
    final results = geoData['results'];
    if (results == null || results.isEmpty) throw Exception('City not found');

    final lat = results[0]['latitude'];
    final lon = results[0]['longitude'];
    final name = results[0]['name'];

    return await fetchFullWeather(lat, lon, name);
  }

  /// Fetch weather by GPS coords
  Future<Map<String, dynamic>> getWeatherByCoords(double lat, double lon) async {
    // Reverse geocode to get city name
    final geoUrl = 'https://geocoding-api.open-meteo.com/v1/search?name=&latitude=$lat&longitude=$lon&count=1&language=en&format=json';
    String cityName = 'Current Location';
    
    try {
      // Try reverse lookup via a nearby search
      final revUrl = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m&timezone=auto';
      // Just use "Current Location" — reverse geocoding not available in Open-Meteo
    } catch (_) {}

    return await fetchFullWeather(lat, lon, cityName);
  }

  /// Core method: fetches weather + AQI + 7-day forecast
  Future<Map<String, dynamic>> fetchFullWeather(double lat, double lon, String cityName) async {
    // Fetch weather with hourly data, daily forecast, and current conditions
    final weatherUrl = 'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m'
        '&daily=temperature_2m_max,temperature_2m_min,weather_code'
        '&timezone=auto';

    // Fetch Air Quality
    final aqiUrl = 'https://air-quality-api.open-meteo.com/v1/air-quality'
        '?latitude=$lat&longitude=$lon'
        '&current=european_aqi';

    // Fire both requests in parallel
    final responses = await Future.wait([
      http.get(Uri.parse(weatherUrl)),
      http.get(Uri.parse(aqiUrl)),
    ]);

    final weatherRes = responses[0];
    final aqiRes = responses[1];

    if (weatherRes.statusCode != 200) throw Exception('Weather fetch failed');

    final weather = json.decode(weatherRes.body);
    final current = weather['current'];
    final daily = weather['daily'];

    // Parse AQI (graceful fallback)
    int aqi = 0;
    try {
      if (aqiRes.statusCode == 200) {
        final aqiData = json.decode(aqiRes.body);
        aqi = (aqiData['current']?['european_aqi'] ?? 0).toInt();
      }
    } catch (_) {}

    // Build 7-day forecast
    List<Map<String, dynamic>> forecast = [];
    if (daily != null && daily['time'] != null) {
      final times = daily['time'] as List;
      final maxTemps = daily['temperature_2m_max'] as List;
      final minTemps = daily['temperature_2m_min'] as List;
      final codes = daily['weather_code'] as List;
      for (int i = 0; i < times.length && i < 7; i++) {
        forecast.add({
          'date': times[i],
          'temp_max': maxTemps[i],
          'temp_min': minTemps[i],
          'weather_code': codes[i],
        });
      }
    }

    return {
      'name': cityName,
      'lat': lat,
      'lon': lon,
      'main': {
        'temp': current['temperature_2m'],
        'temp_max': daily['temperature_2m_max'][0],
        'temp_min': daily['temperature_2m_min'][0],
        'humidity': current['relative_humidity_2m'],
        'feels_like': current['apparent_temperature'],
        'wind_speed': current['wind_speed_10m'],
      },
      'weather_code': current['weather_code'],
      'aqi': aqi,
      'forecast': forecast,
    };
  }

  /// Search cities — returns list with lat/lon for direct fetch
  Future<List<dynamic>> searchCities(String query) async {
    if (query.isEmpty) return [];

    final encoded = Uri.encodeComponent(query);
    final res = await http.get(
      Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=$encoded&count=10&language=en&format=json'),
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data['results'] == null) return [];

      return (data['results'] as List).map((s) => {
        'name': s['name'],
        'full_name': "${s['name']}, ${s['admin1'] ?? ''}, ${s['country'] ?? ''}",
        'lat': s['latitude'],
        'lon': s['longitude'],
      }).toList();
    }
    return [];
  }

  /// Convert WMO weather code → description + icon
  static Map<String, dynamic> weatherCodeToInfo(int code) {
    if (code == 0) return {'desc': 'Clear Sky', 'icon': '☀️'};
    if (code <= 3) return {'desc': 'Partly Cloudy', 'icon': '⛅'};
    if (code <= 48) return {'desc': 'Foggy', 'icon': '🌫️'};
    if (code <= 55) return {'desc': 'Drizzle', 'icon': '🌦️'};
    if (code <= 57) return {'desc': 'Freezing Drizzle', 'icon': '🌧️'};
    if (code <= 65) return {'desc': 'Rain', 'icon': '🌧️'};
    if (code <= 67) return {'desc': 'Freezing Rain', 'icon': '🌨️'};
    if (code <= 75) return {'desc': 'Snowfall', 'icon': '❄️'};
    if (code == 77) return {'desc': 'Snow Grains', 'icon': '🌨️'};
    if (code <= 82) return {'desc': 'Rain Showers', 'icon': '🌦️'};
    if (code <= 86) return {'desc': 'Snow Showers', 'icon': '🌨️'};
    if (code == 95) return {'desc': 'Thunderstorm', 'icon': '⛈️'};
    if (code <= 99) return {'desc': 'Thunderstorm + Hail', 'icon': '⛈️'};
    return {'desc': 'Unknown', 'icon': '🌡️'};
  }

  /// AQI level description
  static String aqiLabel(int aqi) {
    if (aqi <= 20) return 'Good';
    if (aqi <= 40) return 'Fair';
    if (aqi <= 60) return 'Moderate';
    if (aqi <= 80) return 'Poor';
    if (aqi <= 100) return 'Very Poor';
    return 'Hazardous';
  }

  /// AQI color
  static int aqiColorValue(int aqi) {
    if (aqi <= 20) return 0xFF4CAF50; // green
    if (aqi <= 40) return 0xFF8BC34A; // light green
    if (aqi <= 60) return 0xFFFFEB3B; // yellow
    if (aqi <= 80) return 0xFFFF9800; // orange
    if (aqi <= 100) return 0xFFF44336; // red
    return 0xFF9C27B0; // purple
  }
}
