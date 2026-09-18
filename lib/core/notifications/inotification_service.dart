abstract class INotificationService {
  Future<void> initialize(String appId);
  Future<bool> requestNotificationPermission();
  Future<void> login(String subscription, String token);
  Future<void> handleForegroundNotification();
}
