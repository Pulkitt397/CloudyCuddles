import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:geolocator/geolocator.dart';
import 'package:home_widget/home_widget.dart';
import 'weather_service.dart';

Future<void> _updateHomeWidget(String city, String temp, String desc, String icon) async {
  await HomeWidget.saveWidgetData('location', city);
  await HomeWidget.saveWidgetData('temp', '$temp°');
  await HomeWidget.saveWidgetData('desc', desc);
  await HomeWidget.updateWidget(name: 'CloudyCuddlesWidget', androidName: 'CloudyCuddlesWidget');
}

void main() {
  runApp(const CloudyCuddlesApp());
}

class AppColors {
  static const Color background = Color(0xFFF0F7FF);
  static const Color darkBackground = Color(0xFF000000);
  static const List<Color> dayGradient = [Color(0xFF29B6F6), Color(0xFF039BE5)];
  static const List<Color> nightGradient = [Color(0xFF020617), Color(0xFF1E293B)];
  static const Color accent = Color(0xFF0EA5E9);
}

class CloudyCuddlesApp extends StatefulWidget {
  const CloudyCuddlesApp({super.key});
  @override
  State<CloudyCuddlesApp> createState() => _CloudyCuddlesAppState();
}

class _CloudyCuddlesAppState extends State<CloudyCuddlesApp> {
  ThemeMode _themeMode = ThemeMode.light;
  void toggleTheme() => setState(() => _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);

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
        await _fetchWeather("Alwar");
      }
    } catch (e) {
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
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _fetchWeatherByCoords(double lat, double lon, String cityName) async {
    setState(() => _isLoading = true);
    try {
      final data = await _weatherService.fetchFullWeather(lat, lon, cityName);
      setState(() {
        _weatherData = data;
        _currentLocation = cityName;
        _isLoading = false;
        _currentIndex = 0;
      });
      _syncWidget();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

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
      setState(() => _isLoading = false);
    }
  }

  void _syncWidget() {
    if (_weatherData != null) {
      final temp = (_weatherData!['main']?['temp'] ?? 0).toStringAsFixed(0);
      final info = WeatherService.weatherCodeToInfo(_weatherData!['weather_code'] ?? 0);
      _updateHomeWidget(_currentLocation, temp, info['desc'], info['icon']);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.themeMode == ThemeMode.dark;
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Dynamic Background
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark ? AppColors.nightGradient : AppColors.dayGradient,
              ),
            ),
          ),
          
          SafeArea(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : _weatherData == null
                      ? _buildErrorUI()
                      : WeatherDashboard(data: _weatherData!, onSearch: _showSearch, onLocate: _handleLocationAndFetch),
                WidgetGalleryPage(weatherData: _weatherData),
                SettingsPage(onToggleTheme: widget.onToggleTheme, isDark: isDark),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildiOSNav(isDark),
    );
  }

  Widget _buildErrorUI() {
    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            const Text("Connection Lost", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextButton(onPressed: _handleLocationAndFetch, child: const Text("Try Again", style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _buildiOSNav(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(40, 0, 40, 30),
      height: 64,
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(0, Icons.wb_sunny_rounded, isDark),
              _navItem(1, Icons.grid_view_rounded, isDark),
              _navItem(2, Icons.more_horiz_rounded, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, bool isDark) {
    bool active = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 60,
        alignment: Alignment.center,
        child: Icon(icon, color: active ? Colors.white : Colors.white.withOpacity(0.4), size: 26),
      ),
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
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: widget.themeMode == ThemeMode.dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.5), borderRadius: BorderRadius.circular(2.5))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.1),
                  hintText: "Search for a city",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) async {
                  if (v.length > 1) {
                    setSheetState(() => isSearching = true);
                    final r = await _weatherService.searchCities(v);
                    setSheetState(() { suggestions = r; isSearching = false; });
                  }
                },
              ),
            ),
            Expanded(
              child: isSearching 
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : ListView.separated(
                    itemCount: suggestions.length,
                    separatorBuilder: (c, i) => const Divider(indent: 16, endIndent: 16, height: 1),
                    itemBuilder: (c, i) => ListTile(
                      title: Text(suggestions[i]['full_name']),
                      onTap: () {
                        Navigator.pop(context);
                        _fetchWeatherByCoords(suggestions[i]['lat'], suggestions[i]['lon'], suggestions[i]['name']);
                      },
                    ),
                  ),
            ),
          ]),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  const GlassCard({super.key, required this.child, this.padding, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: child,
          ),
        ),
      ),
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
    final info = WeatherService.weatherCodeToInfo(data['weather_code'] ?? 0);
    final temp = (data['main']?['temp'] ?? 0).toStringAsFixed(0);
    final hi = (data['main']?['temp_max'] ?? 0).toStringAsFixed(0);
    final lo = (data['main']?['temp_min'] ?? 0).toStringAsFixed(0);
    final aqi = data['aqi'] ?? 0;
    final aqiLabel = WeatherService.aqiLabel(aqi);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(icon: const Icon(Icons.location_searching, color: Colors.white, size: 20), onPressed: onLocate),
                Text(data['name'] ?? 'Alwar', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w400)),
                IconButton(icon: const Icon(Icons.list, color: Colors.white, size: 28), onPressed: onSearch),
              ]),
              const SizedBox(height: 40),
              Text('$temp°', style: const TextStyle(color: Colors.white, fontSize: 100, fontWeight: FontWeight.w200)),
              Text(info['desc'], style: const TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w500)),
              Text("H:$hi°  L:$lo°", style: const TextStyle(color: Colors.white60, fontSize: 18, fontWeight: FontWeight.w400)),
              const SizedBox(height: 60),
            ],
          ),
        ),
        
        // AQI List Item
        SliverToBoxAdapter(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              const Icon(Icons.air, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text("AIR QUALITY", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
              Text("$aqi - $aqiLabel", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),

        // 7-Day Forecast
        SliverToBoxAdapter(
          child: GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.calendar_month, color: Colors.white.withOpacity(0.5), size: 16),
                const SizedBox(width: 8),
                Text("10-DAY FORECAST", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ]),
              const SizedBox(height: 16),
              ...(data['forecast'] as List).map((f) => _forecastRow(f)),
            ]),
          ),
        ),

        // Grid details
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _gridItem("HUMIDITY", "${data['main']?['humidity']}%", Icons.water_drop),
              _gridItem("WIND", "${data['main']?['wind_speed']} km/h", Icons.wind_power),
              _gridItem("FEELS LIKE", "${data['main']?['feels_like']}°", Icons.thermostat),
              _gridItem("VISIBILITY", "10 km", Icons.visibility),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _gridItem(String label, String value, IconData icon) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: Colors.white.withOpacity(0.5), size: 14), const SizedBox(width: 6), Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold))]),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w400)),
        const Spacer(),
      ]),
    );
  }

  Widget _forecastRow(dynamic f) {
    final date = DateTime.parse(f['date']);
    final day = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][date.weekday - 1];
    final isToday = DateTime.now().day == date.day;
    final info = WeatherService.weatherCodeToInfo(f['weather_code']);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Row(children: [
        SizedBox(width: 45, child: Text(isToday ? "Today" : day, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500))),
        const Spacer(),
        Text(info['icon'], style: const TextStyle(fontSize: 22)),
        const Spacer(),
        SizedBox(width: 35, child: Text("${f['temp_min']}°", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16, fontWeight: FontWeight.w500))),
        const SizedBox(width: 10),
        // Temperature Bar Mock
        Container(width: 60, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        SizedBox(width: 35, child: Text("${f['temp_max']}°", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// PREMIUM IOS WIDGETS
// ─────────────────────────────────────────────
class WidgetGalleryPage extends StatelessWidget {
  final Map<String, dynamic>? weatherData;
  const WidgetGalleryPage({super.key, this.weatherData});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            title: Text("Smart Stack", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            floating: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            child: SliverList(delegate: SliverChildListDelegate([
              _iosWidgetFrame("Small Weather", "2x2", iOSSmallWidget(data: weatherData)),
              const SizedBox(height: 40),
              _iosWidgetFrame("Medium Forecast", "4x2", iOSMediumWidget(data: weatherData)),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _iosWidgetFrame(String name, String size, Widget child) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        Text(size, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
      ]),
      const SizedBox(height: 16),
      child,
    ]);
  }
}

class iOSSmallWidget extends StatelessWidget {
  final Map<String, dynamic>? data;
  const iOSSmallWidget({super.key, this.data});
  @override
  Widget build(BuildContext context) {
    final info = WeatherService.weatherCodeToInfo(data?['weather_code'] ?? 0);
    return Container(
      width: 155, height: 155,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF5AC8FA), Color(0xFF007AFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data?['name'] ?? 'Alwar', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text("${data?['main']?['temp']?.toStringAsFixed(0) ?? '--'}°", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w300)),
        const Spacer(),
        Text(info['icon'], style: const TextStyle(fontSize: 32)),
        Text(info['desc'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        Text("H:${data?['main']?['temp_max']?.toStringAsFixed(0)}° L:${data?['main']?['temp_min']?.toStringAsFixed(0)}°", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
      ]),
    );
  }
}

class iOSMediumWidget extends StatelessWidget {
  final Map<String, dynamic>? data;
  const iOSMediumWidget({super.key, this.data});
  @override
  Widget build(BuildContext context) {
    final info = WeatherService.weatherCodeToInfo(data?['weather_code'] ?? 0);
    return Container(
      width: double.infinity, height: 155,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data?['name'] ?? 'Alwar', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text("${data?['main']?['temp']?.toStringAsFixed(0) ?? '--'}°", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w200)),
            const Spacer(),
            Text(info['desc'], style: const TextStyle(color: Colors.white60, fontSize: 14)),
            Text("AQI: ${data?['aqi'] ?? '--'}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
        ),
        Expanded(
          flex: 3,
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: 
            (data?['forecast'] as List? ?? []).take(4).map((f) {
              final d = DateTime.parse(f['date']);
              final day = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][d.weekday - 1];
              return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(day, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(WeatherService.weatherCodeToInfo(f['weather_code'])['icon'], style: const TextStyle(fontSize: 16)),
                Text("${f['temp_max']}°", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ]);
            }).toList()
          ),
        ),
      ]),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;
  const SettingsPage({super.key, required this.onToggleTheme, required this.isDark});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: GlassCard(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("Preferences", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _iosSettingItem("Dark Mode", Switch(value: isDark, onChanged: (v) => onToggleTheme(), activeColor: AppColors.accent)),
        _iosSettingItem("Units", const Text("Celsius", style: TextStyle(color: Colors.white38))),
        _iosSettingItem("Notifications", const Text("On", style: TextStyle(color: Colors.white38))),
      ]),
    ),
  );

  Widget _iosSettingItem(String label, Widget trailing) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
      trailing,
    ]),
  );
}
