import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firebase Firestore Manager for Flutter
/// Handles database operations with Firestore
class FirestoreManager {
  static final FirestoreManager _instance = FirestoreManager._internal();
  factory FirestoreManager() => _instance;
  FirestoreManager._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StreamSubscription> _listeners = {};

  /// Enable offline persistence
  void enableOfflinePersistence() {
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  /// Enable network
  Future<void> enableNetwork() async {
    await _firestore.enableNetwork();
  }

  /// Disable network
  Future<void> disableNetwork() async {
    await _firestore.disableNetwork();
  }

  // MARK: - CRUD Operations

  /// Add document
  Future<String> addDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    final docRef = await _firestore.collection(collection).add(data);
    return docRef.id;
  }

  /// Set document
  Future<void> setDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = false,
  }) async {
    await _firestore
        .collection(collection)
        .doc(documentId)
        .set(data, SetOptions(merge: merge));
  }

  /// Get document
  Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  }) async {
    final snapshot =
        await _firestore.collection(collection).doc(documentId).get();

    return snapshot.data();
  }

  /// Update document
  Future<void> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection(collection).doc(documentId).update(data);
  }

  /// Delete document
  Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    await _firestore.collection(collection).doc(documentId).delete();
  }

  /// Check if document exists
  Future<bool> documentExists({
    required String collection,
    required String documentId,
  }) async {
    final snapshot =
        await _firestore.collection(collection).doc(documentId).get();

    return snapshot.exists;
  }

  // MARK: - Query Operations

  /// Get all documents in collection
  Future<List<Map<String, dynamic>>> getAllDocuments({
    required String collection,
  }) async {
    final snapshot = await _firestore.collection(collection).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Query documents with conditions
  Future<List<Map<String, dynamic>>> queryDocuments({
    required String collection,
    Query Function(Query query)? queryBuilder,
  }) async {
    Query query = _firestore.collection(collection);

    if (queryBuilder != null) {
      query = queryBuilder(query);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  /// Query with where clause
  Future<List<Map<String, dynamic>>> queryWhere({
    required String collection,
    required String field,
    required dynamic value,
  }) async {
    final snapshot = await _firestore
        .collection(collection)
        .where(field, isEqualTo: value)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Query with pagination
  Future<QueryResult> queryWithPagination({
    required String collection,
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String orderByField = 'createdAt',
    bool descending = true,
  }) async {
    Query query = _firestore
        .collection(collection)
        .orderBy(orderByField, descending: descending)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.get();
    final items = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    return QueryResult(items: items, lastDocument: lastDoc);
  }

  // MARK: - Real-time Listeners

  /// Listen to document changes
  Stream<Map<String, dynamic>?> listenToDocument({
    required String collection,
    required String documentId,
  }) {
    return _firestore
        .collection(collection)
        .doc(documentId)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  /// Listen to collection changes
  Stream<List<Map<String, dynamic>>> listenToCollection({
    required String collection,
    Query Function(Query query)? queryBuilder,
  }) {
    Query query = _firestore.collection(collection);

    if (queryBuilder != null) {
      query = queryBuilder(query);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
  }

  /// Listen with listener ID for cancellation
  void listenWithId({
    required String listenerId,
    required String collection,
    required void Function(List<Map<String, dynamic>>) onData,
    void Function(Object error)? onError,
    Query Function(Query query)? queryBuilder,
  }) {
    Query query = _firestore.collection(collection);

    if (queryBuilder != null) {
      query = queryBuilder(query);
    }

    final subscription = query.snapshots().listen(
      (snapshot) {
        final items = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        onData(items);
      },
      onError: onError,
    );

    _listeners[listenerId] = subscription;
  }

  /// Remove listener
  void removeListener(String listenerId) {
    _listeners[listenerId]?.cancel();
    _listeners.remove(listenerId);
  }

  /// Remove all listeners
  void removeAllListeners() {
    for (var subscription in _listeners.values) {
      subscription.cancel();
    }
    _listeners.clear();
  }

  // MARK: - Batch Operations

  /// Perform batch write
  Future<void> batchWrite({
    required void Function(WriteBatch batch) operations,
  }) async {
    final batch = _firestore.batch();
    operations(batch);
    await batch.commit();
  }

  /// Batch set documents
  Future<void> batchSetDocuments({
    required String collection,
    required List<DocumentData> documents,
  }) async {
    await batchWrite(operations: (batch) {
      for (var doc in documents) {
        final docRef = _firestore.collection(collection).doc(doc.id);
        batch.set(docRef, doc.data);
      }
    });
  }

  /// Batch update documents
  Future<void> batchUpdateDocuments({
    required String collection,
    required List<DocumentData> documents,
  }) async {
    await batchWrite(operations: (batch) {
      for (var doc in documents) {
        final docRef = _firestore.collection(collection).doc(doc.id);
        batch.update(docRef, doc.data);
      }
    });
  }

  /// Batch delete documents
  Future<void> batchDeleteDocuments({
    required String collection,
    required List<String> documentIds,
  }) async {
    await batchWrite(operations: (batch) {
      for (var id in documentIds) {
        final docRef = _firestore.collection(collection).doc(id);
        batch.delete(docRef);
      }
    });
  }

  // MARK: - Transaction Operations

  /// Run transaction
  Future<T> runTransaction<T>({
    required Future<T> Function(Transaction transaction) updateFunction,
  }) async {
    return await _firestore.runTransaction<T>(updateFunction);
  }

  /// Transfer balance example (transaction)
  Future<void> transferBalance({
    required String fromUserId,
    required String toUserId,
    required double amount,
  }) async {
    await runTransaction(updateFunction: (transaction) async {
      final fromRef = _firestore.collection('users').doc(fromUserId);
      final toRef = _firestore.collection('users').doc(toUserId);

      final fromSnapshot = await transaction.get(fromRef);
      final toSnapshot = await transaction.get(toRef);

      final fromBalance = fromSnapshot.data()?['balance'] as double? ?? 0.0;
      final toBalance = toSnapshot.data()?['balance'] as double? ?? 0.0;

      if (fromBalance < amount) {
        throw Exception('Insufficient balance');
      }

      transaction.update(fromRef, {'balance': fromBalance - amount});
      transaction.update(toRef, {'balance': toBalance + amount});
    });
  }

  // MARK: - Counter Operations

  /// Increment field
  Future<void> incrementField({
    required String collection,
    required String documentId,
    required String field,
    int value = 1,
  }) async {
    await _firestore.collection(collection).doc(documentId).update({
      field: FieldValue.increment(value),
    });
  }

  /// Decrement field
  Future<void> decrementField({
    required String collection,
    required String documentId,
    required String field,
    int value = 1,
  }) async {
    await incrementField(
      collection: collection,
      documentId: documentId,
      field: field,
      value: -value,
    );
  }

  // MARK: - Array Operations

  /// Add to array
  Future<void> arrayUnion({
    required String collection,
    required String documentId,
    required String field,
    required List<dynamic> elements,
  }) async {
    await _firestore.collection(collection).doc(documentId).update({
      field: FieldValue.arrayUnion(elements),
    });
  }

  /// Remove from array
  Future<void> arrayRemove({
    required String collection,
    required String documentId,
    required String field,
    required List<dynamic> elements,
  }) async {
    await _firestore.collection(collection).doc(documentId).update({
      field: FieldValue.arrayRemove(elements),
    });
  }

  // MARK: - Server Timestamp

  /// Set server timestamp
  Future<void> setServerTimestamp({
    required String collection,
    required String documentId,
    required String field,
  }) async {
    await _firestore.collection(collection).doc(documentId).update({
      field: FieldValue.serverTimestamp(),
    });
  }

  // MARK: - Helper Methods

  /// Get collection reference
  CollectionReference collectionReference(String path) {
    return _firestore.collection(path);
  }

  /// Get document reference
  DocumentReference documentReference({
    required String collection,
    required String documentId,
  }) {
    return _firestore.collection(collection).doc(documentId);
  }

  /// Clear cache
  Future<void> clearCache() async {
    await _firestore.clearPersistence();
  }

  /// Dispose
  void dispose() {
    removeAllListeners();
  }
}

/// Query result with pagination
class QueryResult {
  final List<Map<String, dynamic>> items;
  final DocumentSnapshot? lastDocument;

  QueryResult({
    required this.items,
    this.lastDocument,
  });
}

/// Document data helper
class DocumentData {
  final String id;
  final Map<String, dynamic> data;

  DocumentData({
    required this.id,
    required this.data,
  });
}

/// Query builder extensions
extension FirestoreQueryBuilder on Query {
  Query whereEquals(String field, dynamic value) {
    return where(field, isEqualTo: value);
  }

  Query whereNotEquals(String field, dynamic value) {
    return where(field, isNotEqualTo: value);
  }

  Query whereLessThan(String field, dynamic value) {
    return where(field, isLessThan: value);
  }

  Query whereLessThanOrEquals(String field, dynamic value) {
    return where(field, isLessThanOrEqualTo: value);
  }

  Query whereGreaterThan(String field, dynamic value) {
    return where(field, isGreaterThan: value);
  }

  Query whereGreaterThanOrEquals(String field, dynamic value) {
    return where(field, isGreaterThanOrEqualTo: value);
  }

  Query whereArrayContains(String field, dynamic value) {
    return where(field, arrayContains: value);
  }

  Query whereArrayContainsAny(String field, List<dynamic> values) {
    return where(field, arrayContainsAny: values);
  }

  Query whereIn(String field, List<dynamic> values) {
    return where(field, whereIn: values);
  }

  Query whereNotIn(String field, List<dynamic> values) {
    return where(field, whereNotIn: values);
  }

  Query orderByAscending(String field) {
    return orderBy(field, descending: false);
  }

  Query orderByDescending(String field) {
    return orderBy(field, descending: true);
  }
}
