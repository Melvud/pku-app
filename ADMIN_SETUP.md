# Admin Panel Setup Guide

This guide explains how to configure and use the admin panel in the PKU Diet Tracker app.

## Quick Setup

### 1. Make a User an Admin

To grant admin privileges to a user:

1. **Open Firebase Console**
   - Go to https://console.firebase.google.com
   - Select your PKU app project

2. **Navigate to Firestore Database**
   - Click on "Firestore Database" in the left sidebar
   - Click on the `users` collection

3. **Find the User**
   - Locate the user document by their UID (User ID)
   - You can find the UID in Firebase Authentication > Users section

4. **Add Admin Field**
   - Click on the user document to edit it
   - Add a new field:
     - Field: `isAdmin`
     - Type: `boolean`
     - Value: `true`
   - Save the changes

5. **Verify**
   - The user needs to log out and log back in
   - The "Админ" (Admin) tab will now appear in the bottom navigation

## Admin Panel Features

### Statistics Tab

The statistics tab provides an overview of app usage:

- **Total Users**: Total number of registered users
- **Active Users**: Users who created diary entries in the last 7 days
- **Recipe Statistics**:
  - Total recipes in the database
  - Number of approved recipes
  - Number of pending recipes awaiting approval
- **Activity Metrics**: Total diary entries created in the last 30 days

**Usage:**
- Pull down to refresh statistics
- Click "Обновить статистику" to manually refresh

### Recipe Approval Tab

This tab shows all recipes submitted by users that are pending approval.

**For Each Recipe You Can:**
1. **View Details**: See full recipe information including:
   - Recipe name and description
   - Category and cooking time
   - Ingredients list
   - Nutritional information (Phe, protein, calories)
   - Author name and submission date

2. **Approve**: Click "Одобрить" button
   - Recipe becomes visible to all users
   - Status changes to "approved"
   - Appears in the recipes screen for everyone

3. **Reject**: Click "Отклонить" button
   - You must provide a reason for rejection
   - User receives feedback about why their recipe was rejected
   - Recipe status changes to "rejected"

**Best Practices:**
- Review recipes carefully for accuracy
- Check nutritional values are reasonable
- Ensure ingredients match the nutritional data
- Provide constructive feedback when rejecting

### Articles Management Tab

Manage educational PDF articles about PKU.

**Upload New Article:**
1. Click "Добавить статью" button
2. Enter article title (required)
3. Enter description (optional but recommended)
4. Click "Выбрать PDF файл" to select a PDF from your device
5. Click "Добавить" to upload

**Upload Process:**
- The PDF is uploaded to Firebase Storage
- A record is created in Firestore
- Article immediately appears in the Articles screen for all users

**Delete Article:**
- Click the trash icon on any article card
- Confirm deletion
- Article is removed from the database (PDF file remains in Storage)

**Notes:**
- Only PDF files are supported
- Articles are visible to all users immediately after upload
- Include comprehensive titles and descriptions for better user experience

## Permissions & Security

### Firestore Rules

Recommended Firestore security rules for admin features:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function to check if user is admin
    function isAdmin() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
    
    // Users can only read/write their own profile
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
      // Admins can read any user profile (for stats)
      allow read: if request.auth != null && isAdmin();
    }
    
    // Recipes
    match /recipes/{recipeId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      // Only recipe author or admin can update
      allow update: if request.auth != null && 
                       (request.auth.uid == resource.data.authorId || isAdmin());
      // Only admin can delete
      allow delete: if request.auth != null && isAdmin();
    }
    
    // Articles - only admins can write
    match /articles/{articleId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && isAdmin();
    }
    
    // Diary entries
    match /diary/{entryId} {
      allow read: if request.auth != null && request.auth.uid == resource.data.userId;
      allow write: if request.auth != null && request.auth.uid == request.resource.data.userId;
      // Admins can read for statistics
      allow read: if request.auth != null && isAdmin();
    }
  }
}
```

### Storage Rules

Recommended Storage rules for PDF uploads:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Helper function to check if user is admin
    function isAdmin() {
      return request.auth != null && 
             firestore.get(/databases/(default)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
    
    // Articles folder - only admins can upload
    match /articles/{filename} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }
  }
}
```

## Troubleshooting

### Admin Tab Not Showing

**Problem**: User has `isAdmin: true` but tab doesn't appear

**Solutions:**
1. Make sure user logged out and logged back in
2. Check the field name is exactly `isAdmin` (case-sensitive)
3. Check the value is boolean `true`, not string "true"
4. Clear app data and log in again

### Cannot Upload Articles

**Problem**: "Permission denied" error when uploading PDF

**Solutions:**
1. Check Firebase Storage rules allow admin writes
2. Verify `isAdmin` field is set correctly in Firestore
3. Check Firebase Storage is enabled in console
4. Verify internet connection

### Statistics Not Loading

**Problem**: Statistics tab shows error or empty data

**Solutions:**
1. Check Firestore rules allow admin to read all collections
2. Verify user has `isAdmin: true`
3. Check internet connection
4. Try pulling to refresh

### Recipe Approval Not Working

**Problem**: Cannot approve or reject recipes

**Solutions:**
1. Check Firestore rules allow recipe updates by admins
2. Verify `isAdmin` field is set
3. Check recipe has valid `id` field
4. Review browser console for detailed errors

## Tips for Admins

1. **Review Regularly**: Check pending recipes daily to keep users engaged
2. **Be Constructive**: When rejecting recipes, provide helpful feedback
3. **Verify Data**: Cross-check nutritional values with reliable sources
4. **Organize Articles**: Use clear titles and descriptions for easy discovery
5. **Monitor Stats**: Watch active user trends to understand app usage
6. **Test Features**: Periodically test the approval workflow to ensure it works

## Support

For technical issues or questions about the admin panel, contact the development team or create an issue in the repository.
