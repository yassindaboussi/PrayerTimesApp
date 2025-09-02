import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class PrayerTimesScreen extends StatefulWidget {
  @override
  _PrayerTimesScreenState createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? prayerData;
  bool isLoading = true;
  String currentTime = '';
  Timer? timer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _remainingMinutes = 0;
  int _remainingSeconds = 0;

  String city = 'Tunis';
  String country = 'Tunisia';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    fetchPrayerTimes();
    startClock();
    _animationController.forward();
  }

  void startClock() {
    timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      if (mounted) {
        setState(() {
          currentTime = TimeOfDay.now().format(context);
          _calculateTimeToNextPrayer();
        });
      }
    });
  }

  void _calculateTimeToNextPrayer() {
    if (prayerData == null || prayerData!['data'] == null) return;

    final now = DateTime.now();
    final nextPrayerName = getNextPrayer();

    if (nextPrayerName.isEmpty) return;

    final timings = prayerData!['data']['timings'] as Map<String, dynamic>?;
    if (timings == null) return;

    final nextPrayerTimeStr = timings[nextPrayerName] as String?;
    if (nextPrayerTimeStr == null) return;

    final nextPrayerTime = _parseTimeToDateTime(nextPrayerTimeStr);
    final difference = nextPrayerTime.difference(now);

    setState(() {
      if (difference.isNegative) {
        final tomorrow = nextPrayerTime.add(Duration(days: 1));
        final diff = tomorrow.difference(now);
        _remainingMinutes = diff.inMinutes;
        _remainingSeconds = diff.inSeconds % 60;
      } else {
        _remainingMinutes = difference.inMinutes;
        _remainingSeconds = difference.inSeconds % 60;
      }
    });
  }

  DateTime _parseTimeToDateTime(String timeString) {
    try {
      final parts = timeString.split(':');
      final now = DateTime.now();
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    } catch (e) {
      return DateTime.now();
    }
  }

  Future<void> fetchPrayerTimes() async {
    setState(() => isLoading = true);

    try {
      final now = DateTime.now();
      final dateString =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final url =
          'http://api.aladhan.com/v1/timingsByCity/$dateString?city=$city&country=$country';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['data'] != null) {
          setState(() {
            prayerData = data;
            isLoading = false;
          });
          _calculateTimeToNextPrayer();
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to load prayer times: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching prayer times: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: fetchPrayerTimes,
            ),
          ),
        );
      }
    }
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => LocationSelectionDialog(
        currentCity: city,
        currentCountry: country,
        onLocationSelected: (newCity, newCountry) {
          setState(() {
            city = newCity;
            country = newCountry;
          });
          fetchPrayerTimes();
        },
      ),
    );
  }

  String getNextPrayer() {
    if (prayerData == null || prayerData!['data'] == null) return '';

    final timings = prayerData!['data']['timings'] as Map<String, dynamic>?;
    if (timings == null) return '';

    final now = TimeOfDay.now();
    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    for (String prayer in prayers) {
      final prayerTimeStr = timings[prayer] as String?;
      if (prayerTimeStr != null) {
        final prayerTime = _parseTime(prayerTimeStr);
        if (_isTimeAfter(prayerTime, now)) {
          return prayer;
        }
      }
    }

    return 'Fajr';
  }

  String getCurrentPrayer() {
    if (prayerData == null || prayerData!['data'] == null) return '';

    final timings = prayerData!['data']['timings'] as Map<String, dynamic>?;
    if (timings == null) return '';

    final now = TimeOfDay.now();
    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    String currentPrayer = '';
    for (int i = 0; i < prayers.length; i++) {
      final prayerTimeStr = timings[prayers[i]] as String?;
      if (prayerTimeStr != null) {
        final prayerTime = _parseTime(prayerTimeStr);
        if (_isTimeAfter(now, prayerTime) || _isTimeEqual(now, prayerTime)) {
          currentPrayer = prayers[i];
        }
      }
    }

    return currentPrayer.isEmpty ? 'Isha' : currentPrayer;
  }

  String getCurrentPrayerEndTime() {
    final currentPrayer = getCurrentPrayer();
    if (currentPrayer.isEmpty) return '';

    final timings = prayerData!['data']['timings'] as Map<String, dynamic>?;
    if (timings == null) return '';

    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final currentIndex = prayers.indexOf(currentPrayer);
    
    if (currentIndex == -1 || currentIndex == prayers.length - 1) {
      return timings['Fajr'] ?? '';
    }
    
    return timings[prayers[currentIndex + 1]] ?? '';
  }

  TimeOfDay _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return TimeOfDay.now();
    }
  }

  bool _isTimeAfter(TimeOfDay time1, TimeOfDay time2) {
    final minutes1 = time1.hour * 60 + time1.minute;
    final minutes2 = time2.hour * 60 + time2.minute;
    return minutes1 > minutes2;
  }

  bool _isTimeEqual(TimeOfDay time1, TimeOfDay time2) {
    return time1.hour == time2.hour && time1.minute == time2.minute;
  }

  IconData _getPrayerIcon(String prayerName) {
    switch (prayerName) {
      case 'Fajr':
        return Icons.brightness_2;
      case 'Dhuhr':
        return Icons.wb_sunny;
      case 'Asr':
        return Icons.brightness_6;
      case 'Maghrib':
        return Icons.brightness_4;
      case 'Isha':
        return Icons.brightness_3;
      default:
        return Icons.access_time;
    }
  }

  String _formatCountdown() {
    final hours = _remainingMinutes ~/ 60;
    final minutes = _remainingMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${_remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF334155),
            ],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? _buildLoadingState()
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: RefreshIndicator(
                    onRefresh: fetchPrayerTimes,
                    color: Color(0xFF3B82F6),
                    backgroundColor: Color(0xFF1E293B),
                    child: CustomScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader()),
                        SliverToBoxAdapter(child: _buildPrayerCardsRow()),
                        SliverToBoxAdapter(child: _buildPrayersList()),
                        SliverToBoxAdapter(
                          child: SizedBox(height: 20),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              color: Color(0xFF3B82F6),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading Prayer Times',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final dateString = '${_getMonthName(now.month)} ${now.day}, ${now.year}';
    
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prayer Times',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    dateString,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currentTime,
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  SizedBox(height: 4),
                  GestureDetector(
                    onTap: _showLocationDialog,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Color(0xFF3B82F6),
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '$city, $country',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.edit,
                            color: Colors.white70,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPrayerCard() {
    final currentPrayer = getCurrentPrayer();
    final currentPrayerTime = prayerData?['data']?['timings']?[currentPrayer] ?? '';
    final endTime = getCurrentPrayerEndTime();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3B82F6),
              Color(0xFF2563EB),
              Color(0xFF1D4ED8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF3B82F6).withOpacity(0.4),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getPrayerIcon(currentPrayer),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Current Prayer',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              currentPrayer,
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
            SizedBox(height: 8),
            Text(
              currentPrayerTime,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (endTime.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Ends at $endTime',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNextPrayerCard() {
    final nextPrayer = getNextPrayer();
    final nextPrayerTime = prayerData?['data']?['timings']?[nextPrayer] ?? '';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getPrayerIcon(nextPrayer),
                  color: Colors.white70,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Next Prayer',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nextPrayer,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    nextPrayerTime,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Color(0xFF3B82F6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFF3B82F6).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'TIME LEFT',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _formatCountdown(),
                      style: TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerCardsRow() {
    final currentPrayer = getCurrentPrayer();
    final currentPrayerTime = prayerData?['data']?['timings']?[currentPrayer] ?? '';
    final endTime = getCurrentPrayerEndTime();
    final nextPrayer = getNextPrayer();
    final nextPrayerTime = prayerData?['data']?['timings']?[nextPrayer] ?? '';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF3B82F6),
                    Color(0xFF2563EB),
                    Color(0xFF1D4ED8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF3B82F6).withOpacity(0.4),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getPrayerIcon(currentPrayer),
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Current',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currentPrayer,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        currentPrayerTime,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  if (endTime.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Until $endTime',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getPrayerIcon(nextPrayer),
                            color: Colors.white70,
                            size: 16,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Next',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        nextPrayer,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        nextPrayerTime,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFF3B82F6).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(0xFF3B82F6).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _formatCountdown(),
                        style: TextStyle(
                          color: Color(0xFF3B82F6),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayersList() {
    if (prayerData == null || prayerData!['data'] == null) return Container();

    final timings = prayerData!['data']['timings'] as Map<String, dynamic>?;
    if (timings == null) return Container();

    final prayers = [
      {'name': 'Fajr', 'time': timings['Fajr'] ?? 'N/A', 'label': 'Dawn'},
      {'name': 'Dhuhr', 'time': timings['Dhuhr'] ?? 'N/A', 'label': 'Noon'},
      {'name': 'Asr', 'time': timings['Asr'] ?? 'N/A', 'label': 'Afternoon'},
      {'name': 'Maghrib', 'time': timings['Maghrib'] ?? 'N/A', 'label': 'Sunset'},
      {'name': 'Isha', 'time': timings['Isha'] ?? 'N/A', 'label': 'Night'},
    ];

    final currentPrayer = getCurrentPrayer();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Today\'s Schedule',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SizedBox(height: 8),
          ...prayers.asMap().entries.map((entry) {
            final index = entry.key;
            final prayer = entry.value;
            final isCurrentPrayer = prayer['name'] == currentPrayer;

            return Container(
              margin: EdgeInsets.only(bottom: 6),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isCurrentPrayer 
                    ? Color(0xFF3B82F6).withOpacity(0.1)
                    : Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCurrentPrayer 
                      ? Color(0xFF3B82F6).withOpacity(0.3)
                      : Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrentPrayer 
                          ? Color(0xFF3B82F6).withOpacity(0.2)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getPrayerIcon(prayer['name'] as String),
                      color: isCurrentPrayer 
                          ? Color(0xFF3B82F6)
                          : Colors.white70,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prayer['name'] as String,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          prayer['label'] as String,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        prayer['time'] as String,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (isCurrentPrayer) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'NOW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

class LocationSelectionDialog extends StatefulWidget {
  final String currentCity;
  final String currentCountry;
  final Function(String city, String country) onLocationSelected;

  const LocationSelectionDialog({
    Key? key,
    required this.currentCity,
    required this.currentCountry,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  _LocationSelectionDialogState createState() => _LocationSelectionDialogState();
}

class _LocationSelectionDialogState extends State<LocationSelectionDialog> with TickerProviderStateMixin {
  late TextEditingController _cityController;
  late TextEditingController _countryController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isValidating = false;
  String? _errorMessage;

  final List<Map<String, String>> _popularLocations = [
    {'city': 'Tunis', 'country': 'Tunisia', 'flag': '🇹🇳'},
    {'city': 'Ramallah', 'country': 'Palestine', 'flag': '🇵🇸'},
    {'city': 'Mecca', 'country': 'Saudi Arabia', 'flag': '🇸🇦'},
    {'city': 'Medina', 'country': 'Saudi Arabia', 'flag': '🇸🇦'},
    {'city': 'Istanbul', 'country': 'Turkey', 'flag': '🇹🇷'},
    {'city': 'Cairo', 'country': 'Egypt', 'flag': '🇪🇬'},
    {'city': 'Dubai', 'country': 'United Arab Emirates', 'flag': '🇦🇪'},
    {'city': 'Casablanca', 'country': 'Morocco', 'flag': '🇲🇦'},
    {'city': 'Kuala Lumpur', 'country': 'Malaysia', 'flag': '🇲🇾'},
    {'city': 'Jakarta', 'country': 'Indonesia', 'flag': '🇮🇩'},
    {'city': 'London', 'country': 'United Kingdom', 'flag': '🇬🇧'},
    {'city': 'New York', 'country': 'United States', 'flag': '🇺🇸'},
    {'city': 'Toronto', 'country': 'Canada', 'flag': '🇨🇦'},
  ];

  @override
  void initState() {
    super.initState();
    _cityController = TextEditingController(text: widget.currentCity);
    _countryController = TextEditingController(text: widget.currentCountry);
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _slideController.forward();
    _scaleController.forward();
  }

  Future<bool> _validateLocation(String city, String country) async {
    if (city.isEmpty || country.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both city and country';
      });
      return false;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final dateString =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final url = 'http://api.aladhan.com/v1/timingsByCity/$dateString?city=$city&country=$country';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data != null && data['data'] != null;
      } else {
        setState(() {
          _errorMessage = 'Invalid city or country';
        });
        return false;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error validating location';
      });
      return false;
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    _countryController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16),
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            constraints: BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1E293B),
                  Color(0xFF334155),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF3B82F6),
                        Color(0xFF2563EB),
                      ],
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Location',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _cityController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'City',
                          labelStyle: TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          prefixIcon: Icon(Icons.location_city, color: Color(0xFF3B82F6)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Color(0xFF3B82F6),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _countryController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Country',
                          labelStyle: TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          prefixIcon: Icon(Icons.flag, color: Color(0xFF3B82F6)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Color(0xFF3B82F6),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      SizedBox(height: 16),
                      Text(
                        'Popular Locations',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _popularLocations.length,
                          itemBuilder: (context, index) {
                            final location = _popularLocations[index];
                            return GestureDetector(
                              onTap: () {
                                _cityController.text = location['city']!;
                                _countryController.text = location['country']!;
                              },
                              child: Container(
                                width: 140,
                                margin: EdgeInsets.only(right: 12),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      location['flag']!,
                                      style: TextStyle(fontSize: 24),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      location['city']!,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      location['country']!,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(24).copyWith(top: 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isValidating
                            ? null
                            : () async {
                                final city = _cityController.text.trim();
                                final country = _countryController.text.trim();
                                if (await _validateLocation(city, country)) {
                                  widget.onLocationSelected(city, country);
                                  Navigator.of(context).pop();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isValidating
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Apply',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}