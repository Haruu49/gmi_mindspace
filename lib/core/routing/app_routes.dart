/// Every route path in one place. Screens navigate with these constants
/// (or the helpers below) so a typo cannot create a dead link.
abstract final class AppRoutes {
  // Public
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const studentLogin = '/login/student';
  static const counsellorLogin = '/login/counsellor';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const privacy = '/privacy';
  static const help = '/help';
  static const configNeeded = '/config-needed';

  // Student – shell tabs
  static const studentHome = '/student';
  static const mood = '/student/mood';
  static const selfCare = '/student/selfcare';
  static const booking = '/student/booking';
  static const profile = '/student/profile';

  // Student – mood
  static const moodReflect = '/student/mood/reflect';
  static const moodHistory = '/student/mood/history';
  static const moodAnalytics = '/student/mood/analytics';
  static const moodShare = '/student/mood/share';

  // Student – journal
  static const journal = '/student/journal';
  static const journalNew = '/student/journal/new';
  static String journalDetail(String id) => '/student/journal/$id';
  static String journalEdit(String id) => '/student/journal/$id/edit';

  // Student – self-care
  static String selfCareActivity(String id) => '/student/selfcare/activity/$id';
  static const breathing = '/student/selfcare/breathing';
  static const grounding = '/student/selfcare/grounding';
  static const gratitude = '/student/selfcare/gratitude';
  static const selfCareComplete = '/student/selfcare/complete';

  // Student – counselling
  static const bookingNew = '/student/booking/new';
  static String bookingDetail(String id) => '/student/booking/$id';

  // Student – learning hub
  static const learn = '/student/learn';
  static const learnBookmarks = '/student/learn/bookmarks';
  static String learnDetail(String id) => '/student/learn/$id';

  // Student – activities
  static const activities = '/student/activities';
  static String activityDetail(String id) => '/student/activities/$id';
  static String activityFeedback(String id) => '/student/activities/$id/feedback';

  // Student – misc
  static const notifications = '/student/notifications';
  static const profileEdit = '/student/profile/edit';
  static const notificationSettings = '/student/profile/notifications';

  // Counsellor
  static const counsellorHome = '/counsellor';
  static const counsellorAppointments = '/counsellor/appointments';
  static String counsellorAppointment(String id) => '/counsellor/appointments/$id';
  static const counsellorAvailability = '/counsellor/availability';
  static const counsellorProgrammes = '/counsellor/programmes';
  static const counsellorProgrammeNew = '/counsellor/programmes/new';
  static String counsellorProgramme(String id) => '/counsellor/programmes/$id';
  static String counsellorProgrammeEdit(String id) => '/counsellor/programmes/$id/edit';
  static const counsellorContent = '/counsellor/content';
  static const counsellorContentNew = '/counsellor/content/new';
  static String counsellorContentEdit(String id) => '/counsellor/content/$id/edit';
  static const counsellorReports = '/counsellor/reports';
  static const counsellorNotifications = '/counsellor/notifications';
  static const counsellorProfile = '/counsellor/profile';
  static const counsellorProfileEdit = '/counsellor/profile/edit';
  static const adminProfile = '/admin/profile';
  static const adminProfileEdit = '/admin/profile/edit';

  // Administrator
  static const adminHome = '/admin';
  static const adminUsers = '/admin/users';
  static const adminAudit = '/admin/audit';
  static const adminSettings = '/admin/settings';

  /// Routes reachable without signing in.
  static const publicRoutes = {
    splash, welcome, studentLogin, counsellorLogin, register,
    forgotPassword, resetPassword, privacy, help, configNeeded,
  };

  /// Routes reachable whether or not the user is signed in.
  static const alwaysAllowed = {privacy, help};
}
