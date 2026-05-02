import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // Hardcoded API Key as requested
  final String apiKey = "8f972b22e0394f475133606f8546b306"; // Placeholder key
  final String baseUrl = "https://api.openweathermap.org/data/2.5";

  Future<Map<String, dynamic>> getWeather(String cityName) async {
    final response = await http.get(
      Uri.parse('$baseUrl/weather?q=$cityName&appid=$apiKey&units=metric'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Adding a mock AQI for now as it requires a separate API call
      data['aqi'] = 42; 
      return data;
    } else {
      throw Exception('Failed to load weather data');
    }
  }

  Future<Map<String, dynamic>> getWeatherByCoords(double lat, double lon) async {
    final response = await http.get(
      Uri.parse('$baseUrl/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      data['aqi'] = 38;
      return data;
    } else {
      throw Exception('Failed to load weather data');
    }
  }

  Future<List<Map<String, dynamic>>> getForecast(String cityName) async {
    final response = await http.get(
      Uri.parse('$baseUrl/forecast?q=$cityName&appid=$apiKey&units=metric'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['list']);
    } else {
      throw Exception('Failed to load forecast data');
    }
  }

  Future<List<dynamic>> searchCities(String query) async {
    if (query.length < 3) return [];
    
    // Using Teleport API for a more comprehensive city search
    final response = await http.get(
      Uri.parse('https://api.teleport.org/api/cities/?search=$query'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final suggestions = data['_embedded']['city:search-results'] as List;
      
      // We'll return them in a format similar to what we had before
      return suggestions.map((s) => {
        'name': s['matching_full_name'].split(',')[0].trim(),
        'full_name': s['matching_full_name'],
      }).toList();
    } else {
      return [];
    }
  }
}
