// firebase_options.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return web;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDHm8RyJZkToM6xD6MwTb4rAhdRtzJv4Zg',
    authDomain: 'miwodo-84ee5.firebaseapp.com',
    projectId: 'miwodo-84ee5',
    storageBucket: 'miwodo-84ee5.firebasestorage.app',
    messagingSenderId: '827216265995',
    appId: '1:827216265995:android:fdfadb25add9c770bb580e',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDHm8RyJZkToM6xD6MwTb4rAhdRtzJv4Zg',
    appId: '1:827216265995:android:fdfadb25add9c770bb580e',
    messagingSenderId: '827216265995',
    projectId: 'miwodo-84ee5',
    storageBucket: 'miwodo-84ee5.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBuTM4pesCVCYy3YAc2-l4O605zeIEW3qE',
    appId: '1:827216265995:ios:e880975f33a56cc5bb580e',
    messagingSenderId: '827216265995',
    projectId: 'miwodo-84ee5',
    storageBucket: 'miwodo-84ee5.firebasestorage.app',
    iosBundleId: 'com.miwodo.miwodo',
  );
}
