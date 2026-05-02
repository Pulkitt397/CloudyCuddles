import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:geolocator/geolocator.dart';
import 'package:home_widget/home_widget.dart';
import 'weather_service.dart';

Future<void> _updateHomeWidget(String city, String temp) async {
  await HomeWidget.saveWidgetData('location', city);
  await HomeWidget.saveWidgetData('temp', '$temp°');
  await HomeWidget.updateWidget(name: 'CloudyCuddlesWidget', androidName: 'CloudyCuddlesWidget');
}

void main() {
  runApp(const CloudyCuddlesApp());
}

class AppColors {
  static const Color background = Color(0xFFE2F2FF);
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkCardBg = Color(0xFF1E293B);
  static const Color accentBlue = Color(0xFF90D0FF);
}

class CloudyCuddlesApp extends StatefulWidget {
  const CloudyCuddlesApp({super.key});
  @override
  State<CloudyCuddlesApp> createState() => _CloudyCuddlesAppState();
}

class _CloudyCuddlesAppState extends State<CloudyCuddlesApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloudy Cuddles',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
      ),
      home: MainScaffold(onToggleTheme: toggleTheme, themeMode: _themeMode),
    );
  }
}

class MainScaffold extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  const MainScaffold({super.key, required this.onToggleTheme, required this.themeMode});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  String _currentLocation = "Loading...";
  Map<String, dynamic>? _weatherData;
  bool _isLoading = true;
  final WeatherService _weatherService = WeatherService();

  @override
  void initState() {
    super.initState();
    _handleLocationAndFetch();
  }

  Future<void> _handleLocationAndFetch() async {
    setState(() => _isLoading = true);
    try {
      Position? position = await _determinePosition();
      if (position != null) {
        final data = await _weatherService.getWeatherByCoords(position.latitude, position.longitude);
        setState(() {
          _weatherData = data;
          _currentLocation = data['name'];
          _isLoading = false;
        });
        _syncWidget();
      } else {
        // Fallback: fetch by city name
        await _fetchWeather("Alwar");
      }
    } catch (e) {
      print('Location Error: $e');
      await _fetchWeather("Alwar");
    }
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition();
  }

  /// Fetch by lat/lon directly (used when user taps search result)
  Future<void> _fetchWeatherByCoords(double lat, double lon, String cityName) async {
    setState(() => _isLoading = true);
    try {
      final data = await _weatherService.fetchFullWeather(lat, lon, cityName);
      setState(() {
        _weatherData = data;
        _currentLocation = cityName;
        _isLoading = false;
        _currentIndex = 0; // Switch to home tab
      });
      _syncWidget();
    } catch (e) {
      print('Fetch Error: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Fetch by city name (geocodes internally)
  Future<void> _fetchWeather(String city) async {
    setState(() => _isLoading = true);
    try {
      final data = await _weatherService.getWeather(city);
      setState(() {
        _weatherData = data;
        _currentLocation = data['name'] ?? city;
        _isLoading = false;
        _currentIndex = 0;
      });
      _syncWidget();
    } catch (e) {
      print('Weather Fetch Error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _syncWidget() {
    if (_weatherData != null) {
      final temp = (_weatherData!['main']?['temp'] ?? 0).toStringAsFixed(0);
      _updateHomeWidget(_currentLocation, temp);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.themeMode == ThemeMode.dark;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _weatherData == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text("Couldn't load weather data.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _handleLocationAndFetch, 
                          icon: const Icon(Icons.refresh), 
                          label: const Text("Retry")
                        )
                      ],
                    ),
                  )
                : WeatherDashboard(data: _weatherData!, onSearch: _showSearch, onLocate: _handleLocationAndFetch),
          WidgetGalleryPage(weatherData: _weatherData),
          SettingsPage(onToggleTheme: widget.onToggleTheme, isDark: isDark),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  void _showSearch() {
    List<dynamic> suggestions = [];
    bool isSearching = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Search city...", 
                prefixIcon: const Icon(Icons.search), 
                suffixIcon: isSearching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onChanged: (value) async {
                if (value.isNotEmpty) {
                  setSheetState(() => isSearching = true);
                  try {
                    final results = await _weatherService.searchCities(value);
                    setSheetState(() {
                      suggestions = results;
                      isSearching = false;
                    });
                  } catch (e) {
                    setSheetState(() => isSearching = false);
                  }
                } else {
                  setSheetState(() => suggestions = []);
                }
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: suggestions.isEmpty && !isSearching
                ? const Center(child: Text("Start typing to search cities...", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final city = suggestions[index];
                      return ListTile(
                        leading: const Icon(Icons.location_city, color: Colors.lightBlue),
                        title: Text(city['full_name'] ?? city['name']),
                        onTap: () {
                          Navigator.pop(context);
                          // Use lat/lon directly — no re-geocoding!
                          _fetchWeatherByCoords(
                            city['lat'],
                            city['lon'],
                            city['name'],
                          );
                        },
                      );
                    },
                  ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      height: 90,
      decoration: BoxDecoration(color: isDark ? AppColors.darkCardBg : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _navItem(0, Icons.home_rounded, 'Home'),
        _navItem(1, Icons.grid_view_rounded, 'Widgets'),
        _navItem(2, Icons.settings_rounded, 'Settings'),
      ]),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    bool isActive = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(color: isActive ? Colors.lightBlue.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
          child: Icon(icon, color: isActive ? Colors.lightBlue : Colors.grey[400]),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black) : Colors.grey)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// WEATHER DASHBOARD — real data everywhere
// ─────────────────────────────────────────────
class WeatherDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onSearch;
  final VoidCallback onLocate;
  const WeatherDashboard({super.key, required this.data, required this.onSearch, required this.onLocate});

  @override
  Widget build(BuildContext context) {
    final city = data['name'] ?? 'Unknown';
    final temp = (data['main']?['temp'] ?? 0).toStringAsFixed(0);
    final high = (data['main']?['temp_max'] ?? 0).toStringAsFixed(0);
    final low = (data['main']?['temp_min'] ?? 0).toStringAsFixed(0);
    final humidity = data['main']?['humidity'] ?? 0;
    final feelsLike = (data['main']?['feels_like'] ?? 0).toStringAsFixed(0);
    final windSpeed = (data['main']?['wind_speed'] ?? 0).toStringAsFixed(1);
    final weatherCode = data['weather_code'] ?? 0;
    final weatherInfo = WeatherService.weatherCodeToInfo(weatherCode);
    final aqi = data['aqi'] ?? 0;
    final aqiLabel = WeatherService.aqiLabel(aqi);
    final aqiColor = Color(WeatherService.aqiColorValue(aqi));
    final forecast = data['forecast'] as List<dynamic>? ?? [];
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Column(children: [
      // Header
      Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(icon: const Icon(Icons.location_on_outlined, color: Colors.lightBlue), onPressed: onLocate),
        Text('Cloudy Cuddles', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.lightBlue)),
        IconButton(icon: const Icon(Icons.search, color: Colors.lightBlue), onPressed: onSearch),
      ])),

      Expanded(child: SingleChildScrollView(child: Column(children: [
        // Main weather card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(color: isDark ? AppColors.darkCardBg : Colors.white, borderRadius: BorderRadius.circular(40)),
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(city, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              const Icon(Icons.near_me_outlined, size: 20),
            ]),
            const SizedBox(height: 16),
            // Weather icon
            Text(weatherInfo['icon'], style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 8),
            Text(weatherInfo['desc'], style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 12),
            Text('$temp°', style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w800, letterSpacing: -4)),
            Text('Feels like $feelsLike°', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              // AQI chip with real color
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: aqiColor.withOpacity(isDark ? 0.3 : 0.2), borderRadius: BorderRadius.circular(20)),
                child: Text('AQI $aqi · $aqiLabel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: aqiColor)),
              ),
              const SizedBox(width: 16),
              Text('H:$high° L:$low°'),
            ]),
          ]),
        ),

        const SizedBox(height: 16),

        // Stats row: Humidity, Wind, Feels Like
        Row(children: [
          Expanded(child: _statCard('💧', 'Humidity', '$humidity%', isDark)),
          const SizedBox(width: 12),
          Expanded(child: _statCard('💨', 'Wind', '$windSpeed km/h', isDark)),
          const SizedBox(width: 12),
          Expanded(child: _statCard('🌡️', 'Feels', '$feelsLike°', isDark)),
        ]),

        const SizedBox(height: 16),

        // 7-Day Forecast
        _buildForecast(forecast, isDark),

        const SizedBox(height: 20),
      ]))),
    ])));
  }

  Widget _statCard(String emoji, String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ]),
    );
  }

  Widget _buildForecast(List<dynamic> forecast, bool isDark) {
    if (forecast.isEmpty) return const SizedBox.shrink();

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: isDark ? AppColors.darkCardBg : Colors.white, borderRadius: BorderRadius.circular(32)),
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Row(children: [
          Icon(Icons.calendar_today_outlined, size: 18),
          SizedBox(width: 8),
          Text('7-Day Forecast', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 20),
        ...forecast.map((day) {
          final date = DateTime.tryParse(day['date'] ?? '');
          final dayName = date != null ? days[date.weekday - 1] : '??';
          final isToday = date != null && date.day == DateTime.now().day && date.month == DateTime.now().month;
          final code = day['weather_code'] ?? 0;
          final info = WeatherService.weatherCodeToInfo(code);
          final hi = (day['temp_max'] ?? 0).toStringAsFixed(0);
          final lo = (day['temp_min'] ?? 0).toStringAsFixed(0);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(width: 50, child: Text(isToday ? 'Today' : dayName, style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.normal, color: isToday ? Colors.lightBlue : null))),
              Text(info['icon'], style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(child: Text(info['desc'], style: TextStyle(fontSize: 13, color: Colors.grey[500]))),
              Text('$hi°', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(' / $lo°', style: TextStyle(color: Colors.grey[400])),
            ]),
          );
        }),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// WIDGET GALLERY PAGE
// ─────────────────────────────────────────────
class WidgetGalleryPage extends StatelessWidget {
  final Map<String, dynamic>? weatherData;
  const WidgetGalleryPage({super.key, this.weatherData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text("Widget Gallery"), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text("Long press your phone's home screen to add these widgets!", style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 32),
          const Text("SMALL (2X2)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.lightBlue)),
          const SizedBox(height: 12),
          Center(child: SmallWidget(data: weatherData)),
          const SizedBox(height: 40),
          const Text("MEDIUM (2X4)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.lightBlue)),
          const SizedBox(height: 12),
          MediumWidget(data: weatherData),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class SmallWidget extends StatelessWidget {
  final Map<String, dynamic>? data;
  const SmallWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final temp = (data?['main']?['temp'] ?? 0).toStringAsFixed(0);
    final code = data?['weather_code'] ?? 0;
    final info = WeatherService.weatherCodeToInfo(code);

    return Container(
      width: 170, height: 180,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(info['icon'], style: const TextStyle(fontSize: 40)),
          Text('$temp°', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Text(info['desc'], style: const TextStyle(fontSize: 14, color: Colors.lightBlue)),
        ],
      ),
    );
  }
}

class MediumWidget extends StatelessWidget {
  final Map<String, dynamic>? data;
  const MediumWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final city = data?['name'] ?? 'Loading...';
    final temp = (data?['main']?['temp'] ?? 0).toStringAsFixed(0);
    final aqi = data?['aqi'] ?? 0;
    final aqiLabel = WeatherService.aqiLabel(aqi);
    final aqiColor = Color(WeatherService.aqiColorValue(aqi));
    final high = (data?['main']?['temp_max'] ?? 0).toStringAsFixed(0);
    final low = (data?['main']?['temp_min'] ?? 0).toStringAsFixed(0);
    final code = data?['weather_code'] ?? 0;
    final info = WeatherService.weatherCodeToInfo(code);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(city, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            Text('$temp°', style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold)),
          ]),
          Text(info['icon'], style: const TextStyle(fontSize: 48)),
        ]),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: aqiColor.withOpacity(isDark ? 0.3 : 0.2), borderRadius: BorderRadius.circular(20)),
            child: Text('AQI $aqi', style: TextStyle(color: aqiColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Text('H:$high° L:$low°', style: const TextStyle(fontSize: 14)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// SETTINGS PAGE
// ─────────────────────────────────────────────
class SettingsPage extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;
  const SettingsPage({super.key, required this.onToggleTheme, required this.isDark});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Settings"), backgroundColor: Colors.transparent),
    body: ListView(children: [
      SwitchListTile(title: const Text("Dark Mode"), subtitle: const Text("Switch between light and dark themes"), value: isDark, onChanged: (v) => onToggleTheme()),
      const ListTile(title: Text("About Cloudy Cuddles"), subtitle: Text("Version 1.0.0")),
    ]),
  );
}
