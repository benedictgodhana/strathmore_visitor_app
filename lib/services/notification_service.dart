import '../models/visitor.dart';

class NotificationService {
  Future<void> notifyHost(Visitor visitor, String action) async {
    // Implement host notification logic
    // This could be email, SMS, push notification, etc.
    print('Notifying host: ${visitor.name} has $action');
  }
}