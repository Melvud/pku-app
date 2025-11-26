import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/recipe.dart';

class RecipeLoaderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // GitHub Configuration
  static const String _githubOwner = 'Melvud';
  static const String _githubRepo = 'pku-app';
  static const String _githubPath = 'assets/recipes/new_recipes.json';
  static const String _githubBranch = 'main';

  String get _githubToken => dotenv.env['GITHUB_TOKEN'] ?? '';

  // Load recipes from GitHub
  Future<void> loadRecipes() async {
    try {
      debugPrint('🔄 Fetching recipes from GitHub...');

      final url = Uri.parse(
          'https://raw.githubusercontent.com/$_githubOwner/$_githubRepo/$_githubBranch/$_githubPath');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint(
            '⚠️ Failed to fetch recipes from GitHub: ${response.statusCode}');
        return;
      }

      final String jsonString = response.body;
      if (jsonString.isEmpty) return;

      final List<dynamic> jsonList = json.decode(jsonString);
      if (jsonList.isEmpty) return;

      debugPrint(
          '📦 Found ${jsonList.length} items in GitHub file. Checking for new recipes...');

      int addedCount = 0;
      int skippedCount = 0;

      for (final recipeJson in jsonList) {
        if (recipeJson is! Map<String, dynamic>) continue;

        // Skip documentation or metadata keys
        if (recipeJson.keys.any((k) => k.startsWith('_'))) continue;

        final String name = recipeJson['name'] ?? '';
        if (name.isEmpty) continue;

        // Check if recipe with this name already exists
        final QuerySnapshot existingDocs = await _firestore
            .collection('recipes')
            .where('name', isEqualTo: name)
            .limit(1)
            .get();

        if (existingDocs.docs.isNotEmpty) {
          skippedCount++;
          continue;
        }

        // Create new recipe object
        try {
          // For GitHub sync, we assume images are either URLs or we skip local asset upload logic
          // as we can't upload local assets from a remote JSON easily without the assets being present.
          // However, if the user has the assets locally (which they should if they are running the app),
          // we could try to upload them. But for now, let's assume the JSON on GitHub might point to
          // URLs or assets that are already uploaded or handled.

          // If the recipe has local asset paths, we try to upload them if we can find them in the bundle.
          // Since we are running the app, we have access to assets.

          String? imageUrl = recipeJson['imageUrl'];
          if (imageUrl != null && imageUrl.startsWith('assets/')) {
            try {
              imageUrl = await _uploadImage(imageUrl, name, 'cover');
              recipeJson['imageUrl'] = imageUrl;
            } catch (e) {
              debugPrint('⚠️ Could not upload image $imageUrl: $e');
            }
          }

          if (recipeJson['steps'] != null) {
            final steps = recipeJson['steps'] as List<dynamic>;
            for (int i = 0; i < steps.length; i++) {
              final step = steps[i] as Map<String, dynamic>;
              String? stepImageUrl = step['imageUrl'];
              if (stepImageUrl != null && stepImageUrl.startsWith('assets/')) {
                try {
                  stepImageUrl =
                      await _uploadImage(stepImageUrl, name, 'step_$i');
                  step['imageUrl'] = stepImageUrl;
                } catch (e) {
                  debugPrint(
                      '⚠️ Could not upload step image $stepImageUrl: $e');
                }
              }
            }
          }

          final recipe = _createRecipeFromTemplate(recipeJson);

          // Upload to Firestore
          await _firestore.collection('recipes').add(recipe.toFirestore());
          addedCount++;
          debugPrint('✅ Added new recipe from GitHub: $name');
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

  // Update recipe in GitHub
  Future<void> updateRecipeInGitHub(Recipe recipe) async {
    if (_githubToken.isEmpty) {
      debugPrint('⚠️ GitHub Token not found. Skipping GitHub update.');
      return;
    }

    try {
      debugPrint('🔄 Updating recipe "${recipe.name}" in GitHub...');

      // 1. Get current file content and SHA
      final fileData = await _getGitHubFile();
      if (fileData == null) return;

      final String sha = fileData['sha'];
      final String content =
          utf8.decode(base64.decode(fileData['content'].replaceAll('\n', '')));
      final List<dynamic> jsonList = json.decode(content);

      // 2. Find and update the recipe
      bool found = false;
      for (int i = 0; i < jsonList.length; i++) {
        final item = jsonList[i];
        if (item is Map<String, dynamic> && item['name'] == recipe.name) {
          // Update fields
          jsonList[i] = _recipeToJson(recipe,
              item); // Preserve existing fields like documentation if any
          found = true;
          break;
        }
      }

      if (!found) {
        // Add as new if not found (though usually it should be there)
        jsonList.add(_recipeToJson(recipe, {}));
      }

      // 3. Commit changes
      await _updateGitHubFile(jsonList, sha, 'Update recipe: ${recipe.name}');
      debugPrint('✅ Recipe updated in GitHub');
    } catch (e) {
      debugPrint('❌ Error updating recipe in GitHub: $e');
    }
  }

  // Delete recipe from GitHub
  Future<void> deleteRecipeFromGitHub(String recipeName) async {
    if (_githubToken.isEmpty) {
      debugPrint('⚠️ GitHub Token not found. Skipping GitHub delete.');
      return;
    }

    try {
      debugPrint('🔄 Deleting recipe "$recipeName" from GitHub...');

      // 1. Get current file content and SHA
      final fileData = await _getGitHubFile();
      if (fileData == null) return;

      final String sha = fileData['sha'];
      final String content =
          utf8.decode(base64.decode(fileData['content'].replaceAll('\n', '')));
      final List<dynamic> jsonList = json.decode(content);

      // 2. Remove the recipe
      final initialLength = jsonList.length;
      jsonList.removeWhere(
          (item) => item is Map<String, dynamic> && item['name'] == recipeName);

      if (jsonList.length == initialLength) {
        debugPrint('⚠️ Recipe not found in GitHub file.');
        return;
      }

      // 3. Commit changes
      await _updateGitHubFile(jsonList, sha, 'Delete recipe: $recipeName');
      debugPrint('✅ Recipe deleted from GitHub');
    } catch (e) {
      debugPrint('❌ Error deleting recipe from GitHub: $e');
    }
  }

  // Helper: Get GitHub file details
  Future<Map<String, dynamic>?> _getGitHubFile() async {
    final url = Uri.parse(
        'https://api.github.com/repos/$_githubOwner/$_githubRepo/contents/$_githubPath');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $_githubToken',
        'Accept': 'application/vnd.github.v3+json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      debugPrint(
          '❌ Failed to get GitHub file: ${response.statusCode} ${response.body}');
      return null;
    }
  }

  // Helper: Update GitHub file
  Future<void> _updateGitHubFile(
      List<dynamic> newContent, String sha, String message) async {
    final url = Uri.parse(
        'https://api.github.com/repos/$_githubOwner/$_githubRepo/contents/$_githubPath');
    final String encodedContent = base64.encode(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(newContent)));

    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $_githubToken',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'message': message,
        'content': encodedContent,
        'sha': sha,
        'branch': _githubBranch,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Failed to update GitHub file: ${response.statusCode} ${response.body}');
    }
  }

  // Helper: Convert Recipe to JSON for file
  Map<String, dynamic> _recipeToJson(
      Recipe recipe, Map<String, dynamic> existing) {
    // We want to keep the structure compatible with our JSON template
    return {
      'name': recipe.name,
      'description': recipe.description,
      'category': recipe.category.name,
      'ingredients': recipe.ingredients.map((i) => i.toMap()).toList(),
      'instructions': recipe.instructions, // Keep for backward compatibility
      'steps': recipe.steps?.map((s) => s.toMap()).toList(),
      'servings': recipe.servings,
      'cookingTimeMinutes': recipe.cookingTimeMinutes,
      'phePer100g': recipe.phePer100g,
      'proteinPer100g': recipe.proteinPer100g,
      'fatPer100g': recipe.fatPer100g,
      'carbsPer100g': recipe.carbsPer100g,
      'caloriesPer100g': recipe.caloriesPer100g,
      'imageUrl': recipe.imageUrl, // This might be a URL now
      // Preserve documentation if it exists in the original item
      if (existing.containsKey('_documentation'))
        '_documentation': existing['_documentation'],
    };
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
      rethrow;
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
      isOfficial: false, // Changed from true
      isRecommended: true,
      likesCount: 0,
      likedBy: [],
    );
  }
}
