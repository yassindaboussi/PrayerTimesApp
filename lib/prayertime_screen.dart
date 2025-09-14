import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'widgets/location_selection_dialog.dart';
import 'utils/prayer_utils.dart';

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
      duration: Duration(milliseconds: 800),
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
    final nextPrayerName = getNextPrayer(prayerData);

    if (nextPrayerName.isEmpty) return;

    final timings = prayerData!['data']['timings'] as Map<String, dynamic>?;
    if (timings == null) return;

    final nextPrayerTimeStr = timings[nextPrayerName] as String?;
    if (nextPrayerTimeStr == null) return;

    final nextPrayerTime = parseTimeToDateTime(nextPrayerTimeStr);
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
              Color(0xFF2D3748),
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
                        SliverToBoxAdapter(child: _buildNextPrayerSection()),
                        SliverToBoxAdapter(child: _buildPrayerSchedule()),
                        SliverToBoxAdapter(child: SizedBox(height: 24)),
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
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              color: Color(0xFF3B82F6),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading Prayer Times',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Please wait...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final dateString = '${getMonthName(now.month)} ${now.day}, ${now.year}';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prayer Times',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 4),
              Text(
                dateString,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: _showLocationDialog,
            child: Container(
              constraints: BoxConstraints(maxWidth: 140),
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
                    Icons.location_on_outlined,
                    color: Color(0xFF3B82F6),
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '$city, $country',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.edit_outlined,
                    color: Colors.white70,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextPrayerSection() {
    final currentPrayer = getCurrentPrayer(prayerData);
    final currentPrayerTime = prayerData?['data']?['timings']?[currentPrayer] ?? '';
    final nextPrayer = getNextPrayer(prayerData);
    final nextPrayerTime = prayerData?['data']?['timings']?[nextPrayer] ?? '';
    final countdown = formatCountdown(_remainingMinutes, _remainingSeconds);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B82F6),
            Color(0xFF2563EB),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      getPrayerIcon(currentPrayer),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Now: $currentPrayer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      )],
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  currentPrayerTime,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      getPrayerIcon(nextPrayer),
                      color: Colors.white70,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next: $nextPrayer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          nextPrayerTime,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    countdown,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerSchedule() {
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

    final currentPrayer = getCurrentPrayer(prayerData);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Schedule',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 8),
          ...prayers.map((prayer) {
            final isCurrent = prayer['name'] == currentPrayer;
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              constraints: BoxConstraints(minHeight: 65),
              decoration: BoxDecoration(
                color: isCurrent ? Color(0xFF3B82F6).withOpacity(0.1) : Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent ? Color(0xFF3B82F6).withOpacity(0.3) : Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCurrent ? Color(0xFF3B82F6).withOpacity(0.2) : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          getPrayerIcon(prayer['name'] as String),
                          color: isCurrent ? Color(0xFF3B82F6) : Colors.white70,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                prayer['name'] as String,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              if (isCurrent) ...[
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF3B82F6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Now now',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            prayer['label'] as String,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    prayer['time'] as String,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

}