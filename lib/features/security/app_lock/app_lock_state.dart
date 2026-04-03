library app_lock_state;

enum AppLockPhase { unconfigured, locked, unlocked, loading, error }

class AppLockState {
  const AppLockState({
    required this.phase,
    this.allowBiometric = false,
    this.message,
  });

  const AppLockState.unconfigured({this.message})
    : phase = AppLockPhase.unconfigured,
      allowBiometric = false;

  const AppLockState.locked({this.allowBiometric = false, this.message})
    : phase = AppLockPhase.locked;

  const AppLockState.unlocked({this.allowBiometric = false, this.message})
    : phase = AppLockPhase.unlocked;

  const AppLockState.loading({this.allowBiometric = false, this.message})
    : phase = AppLockPhase.loading;

  const AppLockState.error({this.allowBiometric = false, this.message})
    : phase = AppLockPhase.error;

  final AppLockPhase phase;
  final bool allowBiometric;
  final String? message;

  bool get isUnlocked => phase == AppLockPhase.unlocked;
  bool get requiresSetup => phase == AppLockPhase.unconfigured;
  bool get isLocked => phase == AppLockPhase.locked;
}
