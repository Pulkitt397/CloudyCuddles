import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // Using Open-Meteo (No API key required!)

  Future<Map<String, dynamic>> getWeather(String cityName) async {
    // 1. Get coordinates for the city name
    // Focus on the city name part for better geocoding results
    final cleanCityName = cityName.split(',')[0].trim();
    final encodedCity = Uri.encodeComponent(cleanCityName);
    final geoUrl = 'https://geocoding-api.open-meteo.com/v1/search?name=$encodedCity&count=1&language=en&format=json';
    print('Geocoding city: $cleanCityName (Full: $cityName)');
    
    final geoResponse = await http.get(Uri.parse(geoUrl));

    if (geoResponse.statusCode == 200) {
      print('Geocoding successful for $cityName');
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
    final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m&daily=temperature_2m_max,temperature_2m_min&timezone=auto';
    print('Fetching weather from: $url');
    
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Weather data received for $cityName');
      
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
    
    final encodedQuery = Uri.encodeComponent(query);
    final response = await http.get(
      Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=$encodedQuery&count=10&language=en&format=json'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['results'] == null) return [];
      
      final results = data['results'] as List;
      return results.map((s) => {
        'name': s['name'],
        'full_name': "${s['name']}, ${s['admin1'] ?? ''} ${s['country']}",
      }).toList();
    } else {
      return [];
    }
  }
}
