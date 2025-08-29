import '../models/saved_route.dart';

/// Abstraction for cloud-backed route storage
///
/// Implement this to support syncing routes to a remote backend.
/// The default production implementation uses Firestore.
abstract class RouteCloudService {
  Future<SavedRoute> saveRoute(SavedRoute route);
  Future<List<SavedRoute>> getUserRoutes(String userId);
  Future<List<SavedRoute>> getPublicRoutes({int limit = 50});
  Future<List<SavedRoute>> getAllAccessibleRoutes(String userId);
  Future<void> deleteRoute(String firestoreId);
  Future<List<SavedRoute>> searchPublicRoutes(String query);
  Future<void> updateRouteVisibility(String firestoreId, bool isPublic);
  Stream<List<SavedRoute>> streamUserRoutes(String userId);
  Stream<List<SavedRoute>> streamPublicRoutes({int limit = 50});
}
