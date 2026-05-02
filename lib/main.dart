import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:geolocator/geolocator.dart';
import 'package:home_widget/home_widget.dart';
import 'weather_service.dart';

// ... (in the State class)
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
  String _currentLocation = "Alwar, Rajasthan";
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
      } else {
        _fetchWeather(_currentLocation);
      }
    } catch (e) {
      _fetchWeather(_currentLocation);
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

  Future<void> _fetchWeatherByCoords(double lat, double lon) async {
    final data = await _weatherService.getWeatherByCoords(lat, lon);
    final temp = data['main']['temp'].toStringAsFixed(0);
    setState(() {
      _weatherData = data;
      _currentLocation = data['name'];
      _isLoading = false;
    });
    _updateHomeWidget(_currentLocation, temp);
  }

  Future<void> _fetchWeather(String city) async {
    setState(() => _isLoading = true);
    try {
      final data = await _weatherService.getWeather(city);
      final temp = data['main']['temp'].toStringAsFixed(0);
      setState(() {
        _weatherData = data;
        _currentLocation = city;
        _isLoading = false;
      });
      _updateHomeWidget(city, temp);
    } catch (e) {
      setState(() => _isLoading = false);
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
                if (value.length >= 3) {
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
                ? const Center(child: Text("Type 3 characters to search...", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final city = suggestions[index];
                      return ListTile(
                        leading: const Icon(Icons.location_city, color: Colors.lightBlue),
                        title: Text(city['full_name'] ?? city['name']),
                        onTap: () {
                          _fetchWeather(city['name']);
                          Navigator.pop(context);
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

class WeatherDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onSearch;
  final VoidCallback onLocate;
  const WeatherDashboard({super.key, required this.data, required this.onSearch, required this.onLocate});

  @override
  Widget build(BuildContext context) {
    final city = data['name'];
    final temp = data['main']['temp'].toStringAsFixed(0);
    final high = data['main']['temp_max'].toStringAsFixed(0);
    final low = data['main']['temp_min'].toStringAsFixed(0);
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Column(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(icon: const Icon(Icons.location_on_outlined, color: Colors.lightBlue), onPressed: onLocate),
        Text('Cloudy Cuddles', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.lightBlue)),
        IconButton(icon: const Icon(Icons.search, color: Colors.lightBlue), onPressed: onSearch),
      ])),
      Expanded(child: SingleChildScrollView(child: Column(children: [
        Container(
          width: double.infinity, decoration: BoxDecoration(color: isDark ? AppColors.darkCardBg : Colors.white, borderRadius: BorderRadius.circular(40)),
          padding: const EdgeInsets.all(32), child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(city, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const Icon(Icons.near_me_outlined, size: 20)]),
            const SizedBox(height: 30),
            Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.blue.withOpacity(0.2), Colors.transparent])), child: const Center(child: Icon(Icons.cloud, size: 100, color: Colors.blueGrey))),
            const SizedBox(height: 20),
            Text('$temp°', style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w800, letterSpacing: -4)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.lightBlue[100]!.withOpacity(isDark ? 0.2 : 1), borderRadius: BorderRadius.circular(20)), child: const Text('AQI: 42', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              const SizedBox(width: 16), Text('H:$high° L:$low°'),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        _buildWeeklyOutlook(isDark),
      ]))),
    ])));
  }

  Widget _buildWeeklyOutlook(bool isDark) {
    return Container(
      width: double.infinity, decoration: BoxDecoration(color: isDark ? AppColors.darkCardBg : Colors.white, borderRadius: BorderRadius.circular(32)),
      padding: const EdgeInsets.all(24), child: Column(children: [
        const Row(children: [Icon(Icons.calendar_today_outlined, size: 18), SizedBox(width: 8), Text('Weekly Outlook', style: TextStyle(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((e) => Text(e.value, style: TextStyle(fontWeight: FontWeight.bold, color: e.key == 6 ? Colors.red : Colors.blueGrey))).toList()),
        const SizedBox(height: 16),
        Container(height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [Color(0xFFA5D8FF), Color(0xFFFFD93D), Color(0xFFFF9B9B)])), child: Stack(alignment: Alignment.center, children: [
          Positioned(left: 40, child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.orange))),
          Positioned(right: 40, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: const Text('29°', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)))),
        ])),
      ]),
    );
  }
}

class WidgetGalleryPage extends StatelessWidget {
  final Map<String, dynamic>? weatherData;
  const WidgetGalleryPage({super.key, this.weatherData});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
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

          const Text("WIDE (4X4)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.lightBlue)),
          const SizedBox(height: 12),
          const WideWidget(),
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
    final temp = data?['main']?['temp']?.toStringAsFixed(0) ?? '--';
    
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
          const Icon(Icons.wb_sunny, color: Colors.orange, size: 48),
          Text('$temp°', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const Text('Sunny', style: TextStyle(fontSize: 14, color: Colors.lightBlue)),
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
    final temp = data?['main']?['temp']?.toStringAsFixed(0) ?? '--';
    final aqi = data?['aqi'] ?? '42';
    final high = data?['main']?['temp_max']?.toStringAsFixed(0) ?? '--';
    final low = data?['main']?['temp_min']?.toStringAsFixed(0) ?? '--';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(city, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  Text('$temp°', style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold)),
                ],
              ),
              const Icon(Icons.cloud, color: Colors.blue, size: 48),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.lightBlue[100]!.withOpacity(isDark ? 0.2 : 1), borderRadius: BorderRadius.circular(20)),
                child: Text('AQI $aqi', style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Text('H:$high° L:$low°', style: const TextStyle(fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

class WideWidget extends StatelessWidget {
  const WideWidget({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.calendar_today_outlined, size: 16), SizedBox(width: 8), Text('Weekly Trend', style: TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].map((day) => Column(
              children: [
                Text(day, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Icon(Icons.cloud, size: 20, color: Colors.blueGrey),
                const Text('22°', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;
  const SettingsPage({super.key, required this.onToggleTheme, required this.isDark});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Settings"), backgroundColor: Colors.transparent), body: ListView(children: [
    SwitchListTile(title: const Text("Dark Mode"), subtitle: const Text("Switch between light and dark themes"), value: isDark, onChanged: (v) => onToggleTheme()),
    const ListTile(title: Text("About Cloudy Cuddles"), subtitle: Text("Version 1.0.0")),
  ]));
}
