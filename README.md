# PKU Diet Tracker - PheTracker

A comprehensive Flutter application for tracking phenylalanine (Phe) intake for people with Phenylketonuria (PKU).

## Features

- **Daily Diary**: Track meals and phenylalanine intake throughout the day
- **Recipe Management**: Browse and create recipes with detailed nutritional information
- **Article Library**: Access educational articles about PKU in PDF format
- **Statistics**: View charts and reports of your dietary patterns
- **Admin Panel**: For administrators to manage recipes, articles, and view app statistics

## Admin Panel

### Setting Up an Admin User

To grant admin access to a user:

1. Open Firebase Console for your project
2. Navigate to **Firestore Database**
3. Find the `users` collection
4. Locate the user document (by UID)
5. Add or update the `isAdmin` field:
   ```
   isAdmin: true
   ```

Once this field is set to `true`, the user will see an additional "Админ" tab in the bottom navigation bar.

### Admin Features

The admin panel provides four main sections:

#### 1. Statistics Tab
- Total users count
- Active users (last 7 days)
- Recipe statistics (total, approved, pending)
- Activity metrics (diary entries in last 30 days)

#### 2. Recipes Approval Tab
- Review user-submitted recipes
- View detailed recipe information including:
  - Ingredients and instructions
  - Nutritional values (Phe, protein, calories, etc.)
  - Author information
- Approve recipes to make them public
- Reject recipes with feedback to users

#### 3. Articles Management Tab
- Upload PDF articles about PKU
- Add article titles and descriptions
- Delete existing articles
- All uploaded articles appear in the Articles screen for all users

#### 4. Comments Moderation Tab
- Review user-submitted comments on recipes
- View comment text, author, and associated recipe
- Approve comments to make them visible on recipes
- Reject or delete inappropriate comments
- All comments require moderation before being published

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Firebase project configured
- Android Studio / Xcode for mobile development

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Melvud/pku-app.git
   cd pku-app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Add your `google-services.json` (Android) to `android/app/`
   - Add your `GoogleService-Info.plist` (iOS) to `ios/Runner/`

4. Run the app:
   ```bash
   flutter run
   ```

## Firebase Setup

### Required Collections

1. **users**: User profiles with fields:
   - `name`, `email`, `dateOfBirth`, `weight`, `dailyTolerancePhe`
   - `medicalFormula`, `isAdmin`

2. **recipes**: Recipe data with fields:
   - `name`, `description`, `category`, `ingredients`, `instructions`
   - `status` (pending, approved, rejected)
   - `authorId`, `authorName`
   - Nutritional fields: `phePer100g`, `proteinPer100g`, etc.

3. **articles**: PDF articles with fields:
   - `title`, `description`, `pdfUrl`
   - `createdBy`, `createdByName`, `createdAt`

4. **recipe_comments**: Comments on recipes with fields:
   - `recipeId`, `authorId`, `authorName`
   - `text`, `createdAt`
   - `status` (pending, approved, rejected)

5. **diary**: Daily food entries

### Storage Rules

Configure Firebase Storage for PDF uploads:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /articles/{filename} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      request.auth.token.isAdmin == true;
    }
  }
}
```

### Firestore Security Rules

Ensure proper security rules are set:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /recipes/{recipeId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
                               (request.auth.uid == resource.data.authorId || 
                                get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true);
    }
    
    match /articles/{articleId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
    
    match /recipe_comments/{commentId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
                               get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
    
    match /diary/{entryId} {
      allow read, write: if request.auth != null && request.auth.uid == resource.data.userId;
    }
  }
}
```

## Architecture

- **State Management**: Provider pattern
- **Backend**: Firebase (Auth, Firestore, Storage)
- **UI**: Material Design 3
- **PDF Viewing**: Syncfusion Flutter PDF Viewer

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is private and for internal use only.

## Support

For questions or issues, please contact the development team.
