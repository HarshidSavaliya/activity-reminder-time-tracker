/// ReminderSetting defines the alert timing relative to activity start.
class ReminderSetting {
  final int minutesBefore;
  final bool isEnabled;

  const ReminderSetting({
    this.minutesBefore = 15,
    this.isEnabled = true,
  });

  String get label {
    if (!isEnabled || minutesBefore < 0) return 'No Reminder';
    if (minutesBefore == 0) return 'At activity time';
    if (minutesBefore == 5) return '5 minutes before';
    if (minutesBefore == 10) return '10 minutes before';
    if (minutesBefore == 15) return '15 minutes before';
    if (minutesBefore == 30) return '30 minutes before';
    if (minutesBefore == 60) return '1 hour before';
    if (minutesBefore % 60 == 0) {
      final hours = minutesBefore ~/ 60;
      return '$hours ${hours == 1 ? "hour" : "hours"} before';
    }
    return '$minutesBefore minutes before';
  }

  ReminderSetting copyWith({
    int? minutesBefore,
    bool? isEnabled,
  }) {
    return ReminderSetting(
      minutesBefore: minutesBefore ?? this.minutesBefore,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'minutesBefore': minutesBefore,
      'isEnabled': isEnabled,
    };
  }

  factory ReminderSetting.fromJson(Map<String, dynamic> json) {
    return ReminderSetting(
      minutesBefore: json['minutesBefore'] as int? ?? 15,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }
}
