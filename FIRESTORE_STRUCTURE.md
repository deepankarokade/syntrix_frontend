# Firestore Database Structure

## Collections

### users
Stores user profile and onboarding information.

**Document ID**: Firebase Auth UID

**Fields:**
```javascript
{
  name: string,                    // User's full name
  email: string,                   // User's email address
  createdAt: timestamp,            // Account creation timestamp
  updatedAt: timestamp,            // Last update timestamp
  onboardingCompleted: boolean,    // Whether user completed onboarding
  signInMethod: string,            // "email" or "google" (optional)
  lifeStage: string,               // "pregnant" or "not_pregnant"
  trimester: string,               // Only if pregnant: "1st Trimester (Weeks 1-12)", etc.
}
```

## Data Flow

### 1. Sign Up (Email/Password)
```
User signs up
  ↓
Create Firebase Auth account
  ↓
Save to Firestore:
  - name
  - email
  - createdAt
  - onboardingCompleted: false
  ↓
Navigate to Life Stage Screen
```

### 2. Sign Up (Google)
```
User signs in with Google
  ↓
Create/Get Firebase Auth account
  ↓
Save to Firestore (merge):
  - name (from Google)
  - email (from Google)
  - createdAt
  - onboardingCompleted: false
  - signInMethod: "google"
  ↓
Navigate to Life Stage Screen
```

### 3. Life Stage Selection
```
User selects life stage
  ↓
Update Firestore:
  - lifeStage
  - trimester (if pregnant)
  - updatedAt
  ↓
Navigate to next onboarding step
```

## Firestore Security Rules

Add these rules in Firebase Console → Firestore Database → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      // Allow users to read and write their own data
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Validate user data structure
      allow create: if request.auth != null 
        && request.auth.uid == userId
        && request.resource.data.keys().hasAll(['name', 'email', 'createdAt', 'onboardingCompleted']);
      
      allow update: if request.auth != null 
        && request.auth.uid == userId;
    }
  }
}
```

## Firebase Console Setup

1. **Enable Firestore:**
   - Go to: https://console.firebase.google.com/project/syntrix-430f9/firestore
   - Click "Create database"
   - Choose "Start in production mode"
   - Select a location (closest to your users)

2. **Set Security Rules:**
   - Go to Firestore → Rules tab
   - Paste the security rules above
   - Click "Publish"

3. **Create Indexes (if needed):**
   - Firestore will automatically suggest indexes if queries need them
   - Follow the console prompts to create required indexes

## Querying User Data

### Get current user's data:
```dart
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  
  if (doc.exists) {
    final data = doc.data();
    print('User name: ${data?['name']}');
    print('Life stage: ${data?['lifeStage']}');
  }
}
```

### Listen to user data changes:
```dart
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .listen((snapshot) {
    if (snapshot.exists) {
      final data = snapshot.data();
      print('User data updated: $data');
    }
  });
}
```

## Next Steps

1. Enable Firestore in Firebase Console
2. Set up security rules
3. Test signup and data storage
4. Add more user fields as needed (e.g., profile picture, preferences, etc.)
5. Create additional collections for app features (e.g., health logs, reminders, etc.)
