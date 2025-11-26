import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/recipe.dart';

class RecipeLoaderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _recipesPath = 'assets/recipes/new_recipes.json';

  Future<void> loadRecipes() async {
    try {
      // 1. Check if the file exists and load it
      String jsonString;
      try {
        jsonString = await rootBundle.loadString(_recipesPath);
      } catch (e) {
        debugPrint(
            '⚠️ Recipe file not found at $_recipesPath. Skipping auto-load.');
        return;
      }

      if (jsonString.isEmpty) return;

      final List<dynamic> jsonList = json.decode(jsonString);
      if (jsonList.isEmpty) return;

      debugPrint(
          '📦 Found ${jsonList.length} items in $_recipesPath. Checking for new recipes...');

      int addedCount = 0;
      int skippedCount = 0;

      for (final recipeJson in jsonList) {
        if (recipeJson is! Map<String, dynamic>) continue;

        // Skip documentation or metadata keys
        if (recipeJson.keys.any((k) => k.startsWith('_'))) continue;

        final String name = recipeJson['name'] ?? '';
        if (name.isEmpty) continue;

        // 2. Check if recipe with this name already exists
        final QuerySnapshot existingDocs = await _firestore
            .collection('recipes')
            .where('name', isEqualTo: name)
            .limit(1)
            .get();

        if (existingDocs.docs.isNotEmpty) {
          skippedCount++;
          continue;
        }

        // 3. Process images and create recipe
        try {
          // Upload main image if needed
          String? imageUrl = recipeJson['imageUrl'];
          if (imageUrl != null && imageUrl.startsWith('assets/')) {
            imageUrl = await _uploadImage(imageUrl, name, 'cover');
            recipeJson['imageUrl'] = imageUrl;
          }

          // Upload step images if needed
          if (recipeJson['steps'] != null) {
            final steps = recipeJson['steps'] as List<dynamic>;
            for (int i = 0; i < steps.length; i++) {
              final step = steps[i] as Map<String, dynamic>;
              String? stepImageUrl = step['imageUrl'];
              if (stepImageUrl != null && stepImageUrl.startsWith('assets/')) {
                stepImageUrl =
                    await _uploadImage(stepImageUrl, name, 'step_$i');
                step['imageUrl'] = stepImageUrl;
              }
            }
          }

          final recipe = _createRecipeFromTemplate(recipeJson);

          // 4. Upload to Firestore
          await _firestore.collection('recipes').add(recipe.toFirestore());
          addedCount++;
          debugPrint('✅ Added new recipe: $name');
        } catch (e) {
          debugPrint('❌ Error creating recipe "$name": $e');
        }
      }

      debugPrint(
          '🏁 Recipe loading complete. Added: $addedCount, Skipped: $skippedCount');
    } catch (e) {
      debugPrint('❌ Error in RecipeLoaderService: $e');
    }
  }

  Future<String?> _uploadImage(
      String assetPath, String recipeName, String suffix) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List();

      final String fileName =
          '${recipeName.replaceAll(RegExp(r'\s+'), '_').toLowerCase()}_$suffix.jpg';
      final Reference ref = _storage.ref().child('recipes/images/$fileName');

      final UploadTask task = ref.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await task;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('📤 Uploaded image $assetPath -> $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading image $assetPath: $e');
      return null;
    }
  }

  Recipe _createRecipeFromTemplate(Map<String, dynamic> data) {
    // Helper to parse category safely
    RecipeCategory parseCategory(String? value) {
      if (value == null) return RecipeCategory.snack;
      return RecipeCategory.values.firstWhere(
        (e) => e.name == value,
        orElse: () => RecipeCategory.snack,
      );
    }

    // Helper to parse ingredients
    List<RecipeIngredient> parseIngredients(List<dynamic>? list) {
      if (list == null) return [];
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return RecipeIngredient(
          name: map['name'] ?? '',
          amount: (map['amount'] ?? 0).toDouble(),
          unit: map['unit'] ?? 'г',
        );
      }).toList();
    }

    // Helper to parse steps
    List<RecipeStep> parseSteps(List<dynamic>? list) {
      if (list == null) return [];
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return RecipeStep(
          instruction: map['instruction'] ?? '',
          imageUrl: map['imageUrl'],
        );
      }).toList();
    }

    return Recipe(
      id: '', // Firestore will assign ID
      name: data['name'] ?? 'Без названия',
      description: data['description'] ?? '',
      category: parseCategory(data['category']),
      ingredients: parseIngredients(data['ingredients']),
      instructions:
          (data['instructions'] as List<dynamic>?)?.cast<String>() ?? [],
      steps: parseSteps(data['steps']),
      servings: data['servings'] ?? 1,
      cookingTimeMinutes: data['cookingTimeMinutes'] ?? 0,
      phePer100g: (data['phePer100g'] ?? 0).toDouble(),
      proteinPer100g: (data['proteinPer100g'] ?? 0).toDouble(),
      fatPer100g: data['fatPer100g']?.toDouble(),
      carbsPer100g: data['carbsPer100g']?.toDouble(),
      caloriesPer100g: data['caloriesPer100g']?.toDouble(),
      imageUrl: data['imageUrl'],
      authorId: 'admin', // System/Admin ID
      authorName: 'Admin',
      status: RecipeStatus.approved,
      createdAt: DateTime.now(),
      approvedAt: DateTime.now(),
      isOfficial: true,
      isRecommended: true,
      likesCount: 0,
      likedBy: [],
    );
  }
}
