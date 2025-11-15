import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/recipe.dart';
import '../../providers/recipes_provider.dart';
import '../../providers/admin_provider.dart';

class EditRecipeScreen extends StatefulWidget {
  final Recipe recipe;
  final bool isAdmin;

  const EditRecipeScreen({
    super.key,
    required this.recipe,
    this.isAdmin = false,
  });

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _servingsController;
  late TextEditingController _cookingTimeController;
  late TextEditingController _pheController;
  late TextEditingController _proteinController;
  late TextEditingController _fatController;
  late TextEditingController _carbsController;
  late TextEditingController _caloriesController;

  late RecipeCategory _selectedCategory;
  late List<RecipeIngredient> _ingredients;
  late List<RecipeStep> _steps;
  bool _isSubmitting = false;
  File? _newCoverImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.recipe.name);
    _descriptionController = TextEditingController(text: widget.recipe.description);
    _servingsController = TextEditingController(text: widget.recipe.servings.toString());
    _cookingTimeController = TextEditingController(text: widget.recipe.cookingTimeMinutes.toString());
    _pheController = TextEditingController(text: widget.recipe.phePer100g.toString());
    _proteinController = TextEditingController(text: widget.recipe.proteinPer100g.toString());
    _fatController = TextEditingController(text: widget.recipe.fatPer100g?.toString() ?? '');
    _carbsController = TextEditingController(text: widget.recipe.carbsPer100g?.toString() ?? '');
    _caloriesController = TextEditingController(text: widget.recipe.caloriesPer100g?.toString() ?? '');

    _selectedCategory = widget.recipe.category;
    _ingredients = List.from(widget.recipe.ingredients);
    _steps = List.from(widget.recipe.recipeSteps);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _servingsController.dispose();
    _cookingTimeController.dispose();
    _pheController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final amountController = TextEditingController();
        String selectedUnit = 'г';

        return AlertDialog(
          title: const Text('Добавить ингредиент'),
          content: StatefulBuilder(
            builder: (context, setDialogState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Название *',
                    hintText: 'Яблоко',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: amountController,
                        decoration: const InputDecoration(
                          labelText: 'Количество *',
                          hintText: '100',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: selectedUnit,
                        decoration: const InputDecoration(
                          labelText: 'Ед.',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        isExpanded: true,
                        items: ['г', 'мл', 'шт', 'ч.л.', 'ст.л.', 'стакан']
                            .map((unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedUnit = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    amountController.text.isNotEmpty) {
                  setState(() {
                    _ingredients.add(RecipeIngredient(
                      name: nameController.text,
                      amount: double.parse(amountController.text),
                      unit: selectedUnit,
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickCoverImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Обрезать фото',
              toolbarColor: Theme.of(context).colorScheme.primary,
              toolbarWidgetColor: Colors.white,
              activeControlsWidgetColor: Theme.of(context).colorScheme.primary,
              lockAspectRatio: false,
              hideBottomControls: true,
            ),
            IOSUiSettings(
              title: 'Обрезать фото',
              aspectRatioLockEnabled: false,
            ),
          ],
        );

        if (croppedFile != null) {
          setState(() {
            _newCoverImage = File(croppedFile.path);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка выбора фото: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Upload new cover image if selected
      String? coverImageUrl = widget.recipe.imageUrl;
      if (_newCoverImage != null) {
        final coverRef = FirebaseStorage.instance
            .ref()
            .child('recipes')
            .child('${widget.recipe.id}_${DateTime.now().millisecondsSinceEpoch}_cover.jpg');
        await coverRef.putFile(_newCoverImage!);
        coverImageUrl = await coverRef.getDownloadURL();
      }

      final instructionsList = _steps.map((s) => s.instruction).toList();

      final updatedRecipe = widget.recipe.copyWith(
        name: _nameController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        ingredients: _ingredients,
        instructions: instructionsList,
        steps: _steps,
        servings: int.parse(_servingsController.text),
        cookingTimeMinutes: int.parse(_cookingTimeController.text),
        phePer100g: double.parse(_pheController.text),
        proteinPer100g: double.parse(_proteinController.text),
        fatPer100g: _fatController.text.isNotEmpty
            ? double.parse(_fatController.text)
            : null,
        carbsPer100g: _carbsController.text.isNotEmpty
            ? double.parse(_carbsController.text)
            : null,
        caloriesPer100g: _caloriesController.text.isNotEmpty
            ? double.parse(_caloriesController.text)
            : null,
        imageUrl: coverImageUrl,
      );

      if (widget.isAdmin || widget.recipe.isRecommended) {
        // Admin or recommended recipe - update directly
        await Provider.of<AdminProvider>(context, listen: false)
            .updateRecipe(updatedRecipe);
      } else {
        // Regular user recipe - goes through moderation
        await Provider.of<RecipesProvider>(context, listen: false)
            .updateRecipe(updatedRecipe);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.recipe.isRecommended
                  ? '✅ Рецепт успешно обновлен!'
                  : '✅ Рецепт отправлен на модерацию!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать рецепт'),
        actions: [
          if (_isSubmitting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _submitRecipe,
              tooltip: 'Сохранить',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning card for non-recommended recipes
              if (!widget.recipe.isRecommended) ...[
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'После редактирования рецепт будет отправлен на модерацию',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Basic Info
              Text(
                'Основная информация',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Название рецепта *',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Введите название' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Описание *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Введите описание' : null,
              ),
              const SizedBox(height: 16),

              // Cover Image
              Text(
                'Фото рецепта',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickCoverImage,
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _newCoverImage != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _newCoverImage!,
                                width: double.infinity,
                                height: 180,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _newCoverImage = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        )
                      : widget.recipe.imageUrl != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    widget.recipe.imageUrl!,
                                    width: double.infinity,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Нажмите для изменения',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Добавить обложку рецепта',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<RecipeCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Категория *',
                  border: OutlineInputBorder(),
                ),
                items: RecipeCategory.values
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category.displayName),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _servingsController,
                      decoration: const InputDecoration(
                        labelText: 'Порций *',
                        suffixText: 'шт',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Введите кол-во';
                        final num = int.tryParse(value!);
                        if (num == null || num <= 0) return 'Некорректно';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cookingTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Время *',
                        suffixText: 'мин',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Введите время';
                        final num = int.tryParse(value!);
                        if (num == null || num <= 0) return 'Некорректно';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Nutrition Info
              Text(
                'Пищевая ценность (на 100г)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _pheController,
                decoration: const InputDecoration(
                  labelText: 'Фенилаланин (Phe) *',
                  suffixText: 'мг/100г',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Введите Phe';
                  final num = double.tryParse(value!);
                  if (num == null || num < 0) return 'Некорректно';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _proteinController,
                decoration: const InputDecoration(
                  labelText: 'Белок *',
                  suffixText: 'г/100г',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Введите белок';
                  final num = double.tryParse(value!);
                  if (num == null || num < 0) return 'Некорректно';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fatController,
                      decoration: const InputDecoration(
                        labelText: 'Жиры',
                        suffixText: 'г/100г',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _carbsController,
                      decoration: const InputDecoration(
                        labelText: 'Углеводы',
                        suffixText: 'г/100г',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _caloriesController,
                decoration: const InputDecoration(
                  labelText: 'Калории',
                  suffixText: 'ккал/100г',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
              ),
              const SizedBox(height: 32),

              // Ingredients
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ингредиенты',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton.filled(
                    onPressed: _addIngredient,
                    icon: const Icon(Icons.add),
                    tooltip: 'Добавить ингредиент',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_ingredients.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Text(
                      'Ингредиенты не добавлены',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              else
                ...List.generate(_ingredients.length, (index) {
                  final ingredient = _ingredients[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                      ),
                      title: Text(ingredient.name),
                      subtitle: Text('${ingredient.amount} ${ingredient.unit}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => _ingredients.removeAt(index));
                        },
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitRecipe,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'Сохранить изменения',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
