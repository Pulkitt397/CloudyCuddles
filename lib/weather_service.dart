import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // Using Open-Meteo (No API key required!)

  Future<Map<String, dynamic>> getWeather(String cityName) async {
    // 1. Get coordinates for the city name
    final encodedCity = Uri.encodeComponent(cityName);
    final geoResponse = await http.get(
      Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=$encodedCity&count=1&language=en&format=json'),
    );

    if (geoResponse.statusCode == 200) {
      final geoData = json.decode(geoResponse.body);
      if (geoData['results'] == null || geoData['results'].isEmpty) {
        throw Exception('City not found');
      }
      
      final lat = geoData['results'][0]['latitude'];
      final lon = geoData['results'][0]['longitude'];
      final realCityName = geoData['results'][0]['name'];

      // 2. Get the weather using the coordinates
      return await _fetchOpenMeteoData(lat, lon, realCityName);
    } else {
      throw Exception('Failed to load location data');
    }
  }

  Future<Map<String, dynamic>> getWeatherByCoords(double lat, double lon) async {
    // For GPS, we'll just call it "My Location" if we don't reverse geocode
    return await _fetchOpenMeteoData(lat, lon, "Current Location");
  }

  Future<Map<String, dynamic>> _fetchOpenMeteoData(double lat, double lon, String cityName) async {
    final response = await http.get(
      Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m&daily=temperature_2m_max,temperature_2m_min&timezone=auto'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Formatting the data so it matches exactly what our UI expects!
      return {
        'name': cityName,
        'main': {
          'temp': data['current']['temperature_2m'],
          'temp_max': data['daily']['temperature_2m_max'][0],
          'temp_min': data['daily']['temperature_2m_min'][0],
        },
        'aqi': 42, // Mock AQI for now
      };
    } else {
      throw Exception('Failed to load weather data');
    }
  }

  Future<List<dynamic>> searchCities(String query) async {
    if (query.isEmpty) return [];
    
    // Using Teleport API for the instant search bar
    final encodedQuery = Uri.encodeComponent(query);
    final response = await http.get(
      Uri.parse('https://api.teleport.org/api/cities/?search=$encodedQuery'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final suggestions = data['_embedded']['city:search-results'] as List;
      
      return suggestions.map((s) => {
        'name': s['matching_full_name'].split(',')[0].trim(),
        'full_name': s['matching_full_name'],
      }).toList();
    } else {
      return [];
    }
  }
}
