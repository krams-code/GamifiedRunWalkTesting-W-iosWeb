// ════════════════════════════════════════════════════════════════════════════
//  TEST ENVIRONMENT — this copy of the app talks ONLY to the separate
//  Firebase project "hakbanghero---ios-testing". Nothing done here (sign-ups, runs,
//  coins, chats, rule changes) can touch the real "hakbanghero" project.
//
//  Test project: hakbanghero---ios-testing  ("HakbangHero - IOS testing")
//    • Web app → used for web AND Android (same as the real app does)
//    • iOS app → bundle ID com.hakbanghero.app (GoogleService-Info.plist)
// ════════════════════════════════════════════════════════════════════════════

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Shown as a "TEST" ribbon in the app so you always know which data you're on.
const String kFirebaseEnv = 'TEST';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    final FirebaseOptions o;
    if (kIsWeb) {
      o = web;
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          o = android;
        case TargetPlatform.iOS:
          o = ios;
        default:
          o = web;
      }
    }
    if (o.apiKey.startsWith('PASTE_') || o.appId.startsWith('PASTE_') ||
        o.projectId.startsWith('PASTE_')) {
      throw StateError(
          'Test Firebase settings are not filled in yet. Open '
          'lib/firebase_options.dart and paste the values from the '
          'hakbanghero---ios-testing Firebase project.');
    }
    return o;
  }

  // ── Test project values (shared by every platform) ───────────────────────
  static const String _projectId = 'hakbanghero---ios-testing';
  static const String _apiKey = 'AIzaSyD8GhpYgRCQG695sez4c00xHr7wjCf5cRE';
  static const String _senderId = '343069157882'; // "messagingSenderId"
  static const String _bucket = 'hakbanghero---ios-testing.firebasestorage.app'; // xxx.firebasestorage.app

  // ── Web ──────────────────────────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _apiKey,
    authDomain: '$_projectId.firebaseapp.com',
    projectId: _projectId,
    storageBucket: _bucket,
    messagingSenderId: _senderId,
    appId: '1:343069157882:web:81085c13c7d5bfc4871c43', // 1:<senderId>:web:xxxx
  );

  // ── Android (reuses the web app, same as the real app does) ──────────────
  static const FirebaseOptions android = web;

  // ── iOS (needs its own iOS app; a web ID crashes iPhones on launch) ──────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDqKinVtntOtJzRyme3_LJ_NfboJHO6AOA', // "API_KEY" in GoogleService-Info.plist
    appId: '1:343069157882:ios:e09887f5c549b826871c43', // 1:<senderId>:ios:xxxx
    messagingSenderId: _senderId,
    projectId: _projectId,
    storageBucket: _bucket,
    iosClientId:
        '343069157882-ot313jurj45mq0ue63pu2n61u9i7prj2.apps.googleusercontent.com',
    iosBundleId: 'com.hakbanghero.app',
  );
}
