import 'package:shared_preferences/shared_preferences.dart';

/// Claims the one-time developer-support introduction shown immediately after
/// a new user finishes the welcome agreement flow.
class FirstHomeSupportIntroService {
  const FirstHomeSupportIntroService();

  static const preferenceKey = 'first_home_support_intro_seen_v1';

  Future<bool> claimIfUnseen() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(preferenceKey) == true) {
      return false;
    }
    await preferences.setBool(preferenceKey, true);
    return true;
  }
}
