import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
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
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC8CumJU3bNjxXeVgYGup0jgEZlt5_Uj18',
    appId: '1:1082037001747:web:4f8dcac0df9ac87c79a9e6',
    messagingSenderId: '1082037001747',
    projectId: 'syntrix-430f9',
    authDomain: 'syntrix-430f9.firebaseapp.com',
    storageBucket: 'syntrix-430f9.firebasestorage.app',
    measurementId: 'G-9651VCW2BC',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:
        'AIzaSyBsDgDb41CHJ2s5HvwNQ-nl6Eb31RQGEnU', // Use same as web for now
    appId:
        '1:1082037001747:android:83fec15d886e9d3f79a9e6', // Get from Firebase Console if testing on Android
    messagingSenderId: '1082037001747',
    projectId: 'syntrix-430f9',
    authDomain: 'syntrix-430f9.firebaseapp.com',
    storageBucket: 'syntrix-430f9.firebasestorage.app',
  );
}
