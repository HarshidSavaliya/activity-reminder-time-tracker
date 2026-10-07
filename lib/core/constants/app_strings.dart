/// AppStrings centralizes all user-facing strings to ensure consistency,
/// avoid hardcoded duplicate values, and simplify internationalization later.
class AppStrings {
  AppStrings._();

  // App Identity
  static const String appName = 'Activity Reminder Tracker';
  static const String appTagline = 'Smart Activity & Routine Tracker';

  // Navigation
  static const String navHome = 'Home';
  static const String navCalendar = 'Calendar';
  static const String navAdd = 'Add';
  static const String navProfile = 'Profile';

  // Auth
  static const String loginTitle = 'Welcome Back';
  static const String loginSubtitle = 'Sign in to access your activities and reminders';
  static const String registerTitle = 'Create Account';
  static const String registerSubtitle = 'Join Activity Reminder Tracker to organize your daily routines';
  static const String forgotPasswordTitle = 'Reset Password';
  static const String forgotPasswordSubtitle = 'Enter your email to receive password reset instructions';
  static const String emailLabel = 'Email Address';
  static const String emailHint = 'e.g. alex@example.com';
  static const String passwordLabel = 'Password';
  static const String passwordHint = 'Minimum 8 characters';
  static const String confirmPasswordLabel = 'Confirm Password';
  static const String confirmPasswordHint = 'Re-enter your password';
  static const String nameLabel = 'Full Name';
  static const String nameHint = 'e.g. Alex Johnson';
  static const String usernameLabel = 'Username';
  static const String usernameHint = 'e.g. alex_j';
  static const String collegeLabel = 'Organization / Affiliation';
  static const String collegeHint = 'e.g. Company, Team, or University';
  static const String loginButton = 'Sign In';
  static const String registerButton = 'Create Account';
  static const String forgotPasswordButton = 'Reset Password';
  static const String alreadyHaveAccount = 'Already have an account? Sign In';
  static const String dontHaveAccount = "Don't have an account? Sign Up";
  static const String forgotPasswordPrompt = 'Forgot password?';
  static const String logoutConfirm = 'Are you sure you want to sign out?';
  static const String logoutTitle = 'Sign Out';

  // Home Screen
  static const String upNext = 'UP NEXT';
  static const String today = 'TODAY';
  static const String activities = 'Activities';
  static const String completed = 'Completed';
  static const String pending = 'Pending';
  static const String quickAdd = 'Quick Add';
  static const String noUpcoming = 'No upcoming activity right now';
  static const String noActivitiesToday = 'No activities scheduled for today';
  static const String addFirstActivity = 'Tap + to add your first activity or task';

  // Activities
  static const String activityTitleLabel = 'Activity Title';
  static const String activityTitleHint = 'e.g. Team Standup, Workout, or Study Session';
  static const String activityDescriptionLabel = 'Description (Optional)';
  static const String activityDescriptionHint = 'Add notes, action items, or agenda details';
  static const String categoryLabel = 'Category';
  static const String priorityLabel = 'Priority';
  static const String dateLabel = 'Date';
  static const String startTimeLabel = 'Start Time';
  static const String endTimeLabel = 'End Time';
  static const String locationLabel = 'Location / Room';
  static const String locationHint = 'e.g. Meeting Room 2, Studio, or Online';
  static const String reminderLabel = 'Reminder Alert';
  static const String recurrenceLabel = 'Repeat';
  static const String saveActivity = 'Save Activity';
  static const String updateActivity = 'Update Activity';
  static const String deleteActivity = 'Delete Activity';
  static const String deleteActivityConfirm = 'Are you sure you want to delete this activity?';

  // Profile
  static const String editProfile = 'Edit Profile';
  static const String changePassword = 'Change Password';
  static const String notificationSettings = 'Notification Settings';
  static const String themeSettings = 'Appearance & Theme';
  static const String importTimetable = 'Import Schedule from PDF';
  static const String clearData = 'Reset Account Data';

  // Validation
  static const String emailRequired = 'Email address is required';
  static const String emailInvalid = 'Please enter a valid email address';
  static const String passwordRequired = 'Password is required';
  static const String passwordTooShort = 'Password must be at least 8 characters';
  static const String passwordNeedsComplexity = 'Include at least one letter and one number';
  static const String passwordsDoNotMatch = 'Passwords do not match';
  static const String nameRequired = 'Full name is required';
  static const String usernameRequired = 'Username is required';
  static const String titleRequired = 'Activity title is required';
}
