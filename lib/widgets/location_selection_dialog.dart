import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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