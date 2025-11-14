import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/recipe.dart';
import '../../providers/recipes_provider.dart';
import '../../providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _servingsController = TextEditingController(text: '1');
  final _cookingTimeController = TextEditingController();
  final _pheController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _carbsController = TextEditingController();
  final _caloriesController = TextEditingController();

  RecipeCategory _selectedCategory = RecipeCategory.snack;
  List<RecipeIngredient> _ingredients = [];
  List<String> _instructions = [];
  bool _isSubmitting = false;

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
                      flex: 2,
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
                      child: DropdownButtonFormField<String>(
                        value: selectedUnit,
                        decoration: const InputDecoration(
                          labelText: 'Ед.',
                        ),
                        items: ['г', 'мл', 'шт', 'ч.л.', 'ст.л.', 'стакан']
                            .map((unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit),
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

  void _addInstruction() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();

        return AlertDialog(
          title: Text('Шаг ${_instructions.length + 1}'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Описание шага *',
              hintText: 'Нарежьте яблоко на кусочки...',
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _instructions.add(controller.text);
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

  Future<void> _submitRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы один ингредиент'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_instructions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы один шаг приготовления'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final recipesProvider = Provider.of<RecipesProvider>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Необходима авторизация');
      }

      final recipe = Recipe(
        id: '',
        name: _nameController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        ingredients: _ingredients,
        instructions: _instructions,
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
        authorId: user.uid,
        authorName: userProvider.userProfile?.name ?? 'Аноним',
        status: RecipeStatus.pending,
        createdAt: DateTime.now(),
        isOfficial: false,
      );

      await recipesProvider.addRecipe(recipe);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Рецепт отправлен на проверку!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
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
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить рецепт'),
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
              tooltip: 'Отправить на проверку',
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
              // Info card
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ваш рецепт будет проверен модераторами и опубликован после одобрения',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

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
                  hintText: 'Фруктовый салат',
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
                  hintText: 'Краткое описание блюда',
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Введите описание' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<RecipeCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Категория *',
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
                  helperText: 'Обязательное поле',
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
                  helperText: 'Обязательное поле',
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

              TextFormField(
                controller: _fatController,
                decoration: const InputDecoration(
                  labelText: 'Жиры',
                  suffixText: 'г/100г',
                  helperText: 'Необязательное поле',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _carbsController,
                decoration: const InputDecoration(
                  labelText: 'Углеводы',
                  suffixText: 'г/100г',
                  helperText: 'Необязательное поле',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _caloriesController,
                decoration: const InputDecoration(
                  labelText: 'Калории',
                  suffixText: 'ккал/100г',
                  helperText: 'Необязательное поле',
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
                    child: Column(
                      children: [
                        Icon(Icons.egg_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'Ингредиенты не добавлены',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
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

              // Instructions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Способ приготовления',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton.filled(
                    onPressed: _addInstruction,
                    icon: const Icon(Icons.add),
                    tooltip: 'Добавить шаг',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_instructions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.list_alt,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'Шаги не добавлены',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...List.generate(_instructions.length, (index) {
                  final instruction = _instructions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                      ),
                      title: Text(instruction),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => _instructions.removeAt(index));
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
                  icon: const Icon(Icons.send),
                  label: const Text(
                    'Отправить на проверку',
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