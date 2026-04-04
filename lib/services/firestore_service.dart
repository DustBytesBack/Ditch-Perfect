import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Ensures the user is authenticated (anonymously if needed) before writing.
  static Future<void> ensureAuth() async {
    if (Firebase.apps.isEmpty) {
      throw Exception("Firebase is not initialized. Please check your firebase_options.dart and platform support.");
    }
    if (_auth.currentUser == null) {
      try {
        await _auth.signInAnonymously();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'admin-restricted-operation' || e.code == 'unknown') {
          throw Exception(
            "Anonymous authentication failed. Please ensure 'Anonymous' sign-in provider is ENABLED in your Firebase Console (Authentication > Sign-in method). Error: ${e.message}"
          );
        }
        rethrow;
      }
    }
  }

  /// Uploads a timetable preset to the hierarchical Firestore structure.
  static Future<void> uploadTimetable({
    required String university,
    required String semester,
    required String branch,
    required String batch,
    required List<Map<String, String>> subjects,
    required Map<String, dynamic> timetable,
  }) async {
    await ensureAuth();

    // Explicitly create/update parent documents so they appear in listing queries.
    // Firestore doesn't return documents that only exist as subcollection parents.
    final WriteBatch batchWriter = _db.batch();
    
    final uniId = university.trim().toUpperCase();
    final semId = semester.trim().toUpperCase();
    final branchId = branch.trim().toUpperCase();
    final batchId = batch.trim().toUpperCase();

    final uniRef = _db.collection('timetables').doc(uniId);
    final semRef = uniRef.collection('semesters').doc(semId);
    final branchRef = semRef.collection('branches').doc(branchId);
    final finalBatchRef = branchRef.collection('batches').doc(batchId);

    final data = {
      'subjects': subjects,
      'timetable': timetable,
      'createdBy': _auth.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'displayName': {
        'university': university.trim().toUpperCase(),
        'semester': semester.trim().toUpperCase(),
        'branch': branch.trim().toUpperCase(),
        'batch': batch.trim().toUpperCase(),
      }
    };

    batchWriter.set(uniRef, {'lastUpdated': FieldValue.serverTimestamp(), 'name': university.trim().toUpperCase()}, SetOptions(merge: true));
    batchWriter.set(semRef, {'lastUpdated': FieldValue.serverTimestamp(), 'name': semester.trim().toUpperCase()}, SetOptions(merge: true));
    batchWriter.set(branchRef, {'lastUpdated': FieldValue.serverTimestamp(), 'name': branch.trim().toUpperCase()}, SetOptions(merge: true));
    batchWriter.set(finalBatchRef, data, SetOptions(merge: true));

    await batchWriter.commit();
  }

  /// Fetches all available University names from the top-level 'timetables' collection.
  static Future<List<String>> getAvailableUniversities() async {
    final snapshot = await _db.collection('timetables').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Fetches available Semesters for a specific University.
  static Future<List<String>> getAvailableSemesters(String university) async {
    final snapshot = await _db
        .collection('timetables')
        .doc(university.trim().toUpperCase())
        .collection('semesters')
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Fetches available Branches for a specific Semester in a University.
  static Future<List<String>> getAvailableBranches(
    String university,
    String semester,
  ) async {
    final snapshot = await _db
        .collection('timetables')
        .doc(university.trim().toUpperCase())
        .collection('semesters')
        .doc(semester.trim().toUpperCase())
        .collection('branches')
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Fetches available Batches for a specific Branch.
  static Future<List<String>> getAvailableBatches(
    String university,
    String semester,
    String branch,
  ) async {
    final snapshot = await _db
        .collection('timetables')
        .doc(university.trim().toUpperCase())
        .collection('semesters')
        .doc(semester.trim().toUpperCase())
        .collection('branches')
        .doc(branch.trim().toUpperCase())
        .collection('batches')
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Fetches the full timetable document for a specific batch.
  static Future<DocumentSnapshot<Map<String, dynamic>>> getTimetableDoc(
    String university,
    String semester,
    String branch,
    String batch,
  ) async {
    return await _db
        .collection('timetables')
        .doc(university.trim().toUpperCase())
        .collection('semesters')
        .doc(semester.trim().toUpperCase())
        .collection('branches')
        .doc(branch.trim().toUpperCase())
        .collection('batches')
        .doc(batch.trim().toUpperCase())
        .get();
  }

  /// Checks if a timetable document exists and if it's owned by the current user.
  static Future<Map<String, dynamic>> checkTimetableOwnership({
    required String university,
    required String semester,
    required String branch,
    required String batch,
  }) async {
    final doc = await getTimetableDoc(university, semester, branch, batch);
    if (!doc.exists) return {'exists': false, 'isOwner': false};

    final currentUid = _auth.currentUser?.uid;
    final ownerUid = doc.data()?['createdBy'];

    return {
      'exists': true,
      'isOwner': currentUid != null && currentUid == ownerUid,
    };
  }

  /// Fetches all presets created by the current user across the entire tree.
  static Future<List<Map<String, dynamic>>> getUserPresets() async {
    await ensureAuth();
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _db
        .collectionGroup('batches')
        .where('createdBy', isEqualTo: uid)
        .get();

    return snapshot.docs.map((doc) => {
      ...doc.data(),
      'id': doc.id,
      'path': doc.reference.path,
    }).toList();
  }

  /// Deletes a specific preset.
  static Future<void> deletePreset(String path) async {
    await ensureAuth();
    await _db.doc(path).delete();
  }
}
