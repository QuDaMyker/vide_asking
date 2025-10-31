import Foundation
import FirebaseFirestore
import Combine

/// Firebase Firestore Manager for SwiftUI
/// Handles database operations with Firestore
@MainActor
class FirestoreManager: ObservableObject {
    static let shared = FirestoreManager()
    
    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    
    @Published var isOnline: Bool = true
    
    private init() {
        setupNetworkListener()
    }
    
    /// Setup network listener
    private func setupNetworkListener() {
        db.addSnapshotsInSyncListener {
            print("All snapshots in sync")
        }
    }
    
    /// Enable offline persistence
    func enableOfflinePersistence() {
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
    }
    
    /// Enable network
    func enableNetwork() async throws {
        try await db.enableNetwork()
        isOnline = true
    }
    
    /// Disable network
    func disableNetwork() async throws {
        try await db.disableNetwork()
        isOnline = false
    }
    
    // MARK: - CRUD Operations
    
    /// Add document
    func addDocument<T: Encodable>(
        collection: String,
        data: T
    ) async throws -> String {
        let docRef = try db.collection(collection).addDocument(from: data)
        return docRef.documentID
    }
    
    /// Set document
    func setDocument<T: Encodable>(
        collection: String,
        documentId: String,
        data: T,
        merge: Bool = false
    ) async throws {
        if merge {
            try await db.collection(collection)
                .document(documentId)
                .setData(from: data, merge: true)
        } else {
            try await db.collection(collection)
                .document(documentId)
                .setData(from: data)
        }
    }
    
    /// Get document
    func getDocument<T: Decodable>(
        collection: String,
        documentId: String,
        as type: T.Type
    ) async throws -> T? {
        let snapshot = try await db.collection(collection)
            .document(documentId)
            .getDocument()
        
        return try snapshot.data(as: type)
    }
    
    /// Update document
    func updateDocument(
        collection: String,
        documentId: String,
        data: [String: Any]
    ) async throws {
        try await db.collection(collection)
            .document(documentId)
            .updateData(data)
    }
    
    /// Delete document
    func deleteDocument(
        collection: String,
        documentId: String
    ) async throws {
        try await db.collection(collection)
            .document(documentId)
            .delete()
    }
    
    /// Check if document exists
    func documentExists(
        collection: String,
        documentId: String
    ) async throws -> Bool {
        let snapshot = try await db.collection(collection)
            .document(documentId)
            .getDocument()
        
        return snapshot.exists
    }
    
    // MARK: - Query Operations
    
    /// Get all documents in collection
    func getAllDocuments<T: Decodable>(
        collection: String,
        as type: T.Type
    ) async throws -> [T] {
        let snapshot = try await db.collection(collection).getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: type) }
    }
    
    /// Query documents with conditions
    func queryDocuments<T: Decodable>(
        collection: String,
        as type: T.Type,
        queryBuilder: (Query) -> Query
    ) async throws -> [T] {
        let baseQuery = db.collection(collection)
        let query = queryBuilder(baseQuery)
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: type) }
    }
    
    /// Query with where clause
    func queryWhere<T: Decodable>(
        collection: String,
        field: String,
        isEqualTo value: Any,
        as type: T.Type
    ) async throws -> [T] {
        let snapshot = try await db.collection(collection)
            .whereField(field, isEqualTo: value)
            .getDocuments()
        
        return try snapshot.documents.compactMap { try $0.data(as: type) }
    }
    
    /// Query with pagination
    func queryWithPagination<T: Decodable>(
        collection: String,
        as type: T.Type,
        limit: Int,
        lastDocument: DocumentSnapshot? = nil,
        orderBy field: String = "createdAt",
        descending: Bool = true
    ) async throws -> (items: [T], lastSnapshot: DocumentSnapshot?) {
        var query = db.collection(collection)
            .order(by: field, descending: descending)
            .limit(to: limit)
        
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        let snapshot = try await query.getDocuments()
        let items = try snapshot.documents.compactMap { try $0.data(as: type) }
        let lastSnapshot = snapshot.documents.last
        
        return (items, lastSnapshot)
    }
    
    // MARK: - Real-time Listeners
    
    /// Listen to document changes
    func listenToDocument<T: Decodable>(
        collection: String,
        documentId: String,
        as type: T.Type
    ) -> AsyncThrowingStream<T?, Error> {
        AsyncThrowingStream { continuation in
            let listener = db.collection(collection)
                .document(documentId)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        continuation.finish(throwing: error)
                        return
                    }
                    
                    guard let snapshot = snapshot else {
                        continuation.yield(nil)
                        return
                    }
                    
                    do {
                        let data = try snapshot.data(as: type)
                        continuation.yield(data)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            
            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
    
    /// Listen to collection changes
    func listenToCollection<T: Decodable>(
        collection: String,
        as type: T.Type,
        queryBuilder: ((Query) -> Query)? = nil
    ) -> AsyncThrowingStream<[T], Error> {
        AsyncThrowingStream { continuation in
            var query: Query = db.collection(collection)
            
            if let queryBuilder = queryBuilder {
                query = queryBuilder(query)
            }
            
            let listener = query.addSnapshotListener { snapshot, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }
                
                guard let snapshot = snapshot else {
                    continuation.yield([])
                    return
                }
                
                do {
                    let items = try snapshot.documents.compactMap { 
                        try $0.data(as: type)
                    }
                    continuation.yield(items)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
    
    /// Remove listener
    func removeListener(id: String) {
        listeners[id]?.remove()
        listeners.removeValue(forKey: id)
    }
    
    /// Remove all listeners
    func removeAllListeners() {
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Batch Operations
    
    /// Perform batch write
    func batchWrite(
        operations: (WriteBatch) throws -> Void
    ) async throws {
        let batch = db.batch()
        try operations(batch)
        try await batch.commit()
    }
    
    /// Batch set documents
    func batchSetDocuments<T: Encodable>(
        collection: String,
        documents: [(id: String, data: T)]
    ) async throws {
        try await batchWrite { batch in
            for (id, data) in documents {
                let docRef = db.collection(collection).document(id)
                try batch.setData(from: data, forDocument: docRef)
            }
        }
    }
    
    /// Batch update documents
    func batchUpdateDocuments(
        collection: String,
        updates: [(id: String, data: [String: Any])]
    ) async throws {
        try await batchWrite { batch in
            for (id, data) in updates {
                let docRef = db.collection(collection).document(id)
                batch.updateData(data, forDocument: docRef)
            }
        }
    }
    
    /// Batch delete documents
    func batchDeleteDocuments(
        collection: String,
        documentIds: [String]
    ) async throws {
        try await batchWrite { batch in
            for id in documentIds {
                let docRef = db.collection(collection).document(id)
                batch.deleteDocument(docRef)
            }
        }
    }
    
    // MARK: - Transaction Operations
    
    /// Run transaction
    func runTransaction<T>(
        updateBlock: @escaping (Transaction) async throws -> T
    ) async throws -> T {
        return try await db.runTransaction { transaction, errorPointer in
            do {
                return try await updateBlock(transaction)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil as! T
            }
        } as! T
    }
    
    // MARK: - Counter Operations
    
    /// Increment field
    func incrementField(
        collection: String,
        documentId: String,
        field: String,
        by value: Int = 1
    ) async throws {
        try await db.collection(collection)
            .document(documentId)
            .updateData([
                field: FieldValue.increment(Int64(value))
            ])
    }
    
    /// Decrement field
    func decrementField(
        collection: String,
        documentId: String,
        field: String,
        by value: Int = 1
    ) async throws {
        try await incrementField(
            collection: collection,
            documentId: documentId,
            field: field,
            by: -value
        )
    }
    
    // MARK: - Array Operations
    
    /// Add to array
    func arrayUnion(
        collection: String,
        documentId: String,
        field: String,
        elements: [Any]
    ) async throws {
        try await db.collection(collection)
            .document(documentId)
            .updateData([
                field: FieldValue.arrayUnion(elements)
            ])
    }
    
    /// Remove from array
    func arrayRemove(
        collection: String,
        documentId: String,
        field: String,
        elements: [Any]
    ) async throws {
        try await db.collection(collection)
            .document(documentId)
            .updateData([
                field: FieldValue.arrayRemove(elements)
            ])
    }
    
    // MARK: - Server Timestamp
    
    /// Set server timestamp
    func setServerTimestamp(
        collection: String,
        documentId: String,
        field: String
    ) async throws {
        try await db.collection(collection)
            .document(documentId)
            .updateData([
                field: FieldValue.serverTimestamp()
            ])
    }
    
    // MARK: - Helper Methods
    
    /// Get collection reference
    func collectionReference(_ path: String) -> CollectionReference {
        return db.collection(path)
    }
    
    /// Get document reference
    func documentReference(
        collection: String,
        documentId: String
    ) -> DocumentReference {
        return db.collection(collection).document(documentId)
    }
    
    /// Clear cache
    func clearCache() async throws {
        try await db.clearPersistence()
    }
}

// MARK: - Query Builder Extensions

extension FirestoreManager {
    /// Build complex query
    func buildQuery(
        collection: String,
        filters: [QueryFilter] = [],
        orderBy: [(field: String, descending: Bool)] = [],
        limit: Int? = nil
    ) -> Query {
        var query: Query = db.collection(collection)
        
        // Apply filters
        for filter in filters {
            query = filter.apply(to: query)
        }
        
        // Apply ordering
        for order in orderBy {
            query = query.order(by: order.field, descending: order.descending)
        }
        
        // Apply limit
        if let limit = limit {
            query = query.limit(to: limit)
        }
        
        return query
    }
}

/// Query filter
enum QueryFilter {
    case isEqualTo(field: String, value: Any)
    case isNotEqualTo(field: String, value: Any)
    case isLessThan(field: String, value: Any)
    case isLessThanOrEqualTo(field: String, value: Any)
    case isGreaterThan(field: String, value: Any)
    case isGreaterThanOrEqualTo(field: String, value: Any)
    case arrayContains(field: String, value: Any)
    case arrayContainsAny(field: String, values: [Any])
    case whereIn(field: String, values: [Any])
    case whereNotIn(field: String, values: [Any])
    
    func apply(to query: Query) -> Query {
        switch self {
        case .isEqualTo(let field, let value):
            return query.whereField(field, isEqualTo: value)
        case .isNotEqualTo(let field, let value):
            return query.whereField(field, isNotEqualTo: value)
        case .isLessThan(let field, let value):
            return query.whereField(field, isLessThan: value)
        case .isLessThanOrEqualTo(let field, let value):
            return query.whereField(field, isLessThanOrEqualTo: value)
        case .isGreaterThan(let field, let value):
            return query.whereField(field, isGreaterThan: value)
        case .isGreaterThanOrEqualTo(let field, let value):
            return query.whereField(field, isGreaterThanOrEqualTo: value)
        case .arrayContains(let field, let value):
            return query.whereField(field, arrayContains: value)
        case .arrayContainsAny(let field, let values):
            return query.whereField(field, arrayContainsAny: values)
        case .whereIn(let field, let values):
            return query.whereField(field, in: values)
        case .whereNotIn(let field, let values):
            return query.whereField(field, notIn: values)
        }
    }
}
