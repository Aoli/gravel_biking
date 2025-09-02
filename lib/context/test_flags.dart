/// Test/runtime flags to alter behavior in test environments without
/// relying on compile-time defines.
class RuntimeTestFlags {
  /// When true, the splash screen should skip timers/animations and complete
  /// immediately to avoid pending timers in widget tests.
  static bool disableSplash = false;
}
