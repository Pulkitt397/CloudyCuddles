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
    final response = await http.get(
      Uri.parse('https://api.openweathermap.org/geo/1.0/direct?q=$query&limit=5&appid=$apiKey'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return [];
    }
  }
}
