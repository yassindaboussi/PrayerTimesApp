import 'package:flutter/material.dart';

DateTime parseTimeToDateTime(String timeString) {
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

TimeOfDay parseTime(String timeString) {
  try {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  } catch (e) {
    return TimeOfDay.now();
  }
}

bool isTimeAfter(TimeOfDay time1, TimeOfDay time2) {
  final minutes1 = time1.hour * 60 + time1.minute;
  final minutes2 = time2.hour * 60 + time2.minute;
  return minutes1 > minutes2;
}

bool isTimeEqual(TimeOfDay time1, TimeOfDay time2) {
  return time1.hour == time2.hour && time1.minute == time2.minute;
}

IconData getPrayerIcon(String prayerName) {
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

String formatCountdown(int remainingMinutes, int remainingSeconds) {
  final hours = remainingMinutes ~/ 60;
  final minutes = remainingMinutes % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}

String getMonthName(int month) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return months[month - 1];
}

String getNextPrayer(Map<String, dynamic>? prayerData) {
  if (prayerData == null || prayerData['data'] == null) return '';

  final timings = prayerData['data']['timings'] as Map<String, dynamic>?;
  if (timings == null) return '';

  final now = TimeOfDay.now();
  final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  for (String prayer in prayers) {
    final prayerTimeStr = timings[prayer] as String?;
    if (prayerTimeStr != null) {
      final prayerTime = parseTime(prayerTimeStr);
      if (isTimeAfter(prayerTime, now)) {
        return prayer;
      }
    }
  }

  return 'Fajr';
}

String getCurrentPrayer(Map<String, dynamic>? prayerData) {
  if (prayerData == null || prayerData['data'] == null) return '';

  final timings = prayerData['data']['timings'] as Map<String, dynamic>?;
  if (timings == null) return '';

  final now = TimeOfDay.now();
  final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  String currentPrayer = '';
  for (int i = 0; i < prayers.length; i++) {
    final prayerTimeStr = timings[prayers[i]] as String?;
    if (prayerTimeStr != null) {
      final prayerTime = parseTime(prayerTimeStr);
      if (isTimeAfter(now, prayerTime) || isTimeEqual(now, prayerTime)) {
        currentPrayer = prayers[i];
      }
    }
  }

  return currentPrayer.isEmpty ? 'Isha' : currentPrayer;
}

String getCurrentPrayerEndTime(Map<String, dynamic>? prayerData, String currentPrayer) {
  if (prayerData == null || prayerData['data'] == null) return '';

  final timings = prayerData['data']['timings'] as Map<String, dynamic>?;
  if (timings == null) return '';

  final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  final currentIndex = prayers.indexOf(currentPrayer);
  
  if (currentIndex == -1 || currentIndex == prayers.length - 1) {
    return timings['Fajr'] ?? '';
  }
  
  return timings[prayers[currentIndex + 1]] ?? '';
}