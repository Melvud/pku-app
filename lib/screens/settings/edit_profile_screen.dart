import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _personalFormKey = GlobalKey<FormState>();
  final _medicalFormKey = GlobalKey<FormState>();

  // Controllers для личных данных
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _emailController;

  // Controllers для медицинских данных
  late TextEditingController _pheToleranceController;
  late TextEditingController _medicalFormulaController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeControllers();
  }

  void _initializeControllers() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final profile = userProvider.userProfile;

    _nameController = TextEditingController(text: profile?.name ?? '');
    _ageController = TextEditingController(text: profile?.age.toString() ?? '');
    _weightController =
        TextEditingController(text: profile?.weight.toString() ?? '');
    _emailController = TextEditingController(text: profile?.email ?? '');
    _pheToleranceController = TextEditingController(
        text: profile?.dailyTolerancePhe.toString() ?? '');
    _medicalFormulaController =
        TextEditingController(text: profile?.medicalFormula ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _emailController.dispose();
    _pheToleranceController.dispose();
    _medicalFormulaController.dispose();
    super.dispose();
  }

  // Helper method to calculate date of birth from age
  DateTime _calculateDateOfBirth(int age) {
    final now = DateTime.now();
    return DateTime(now.year - age, now.month, now.day);
  }

  Future<void> _saveChanges() async {
    bool isValid = false;

    if (_tabController.index == 0) {
      isValid = _personalFormKey.currentState?.validate() ?? false;
    } else {
      isValid = _medicalFormKey.currentState?.validate() ?? false;
    }

    if (!isValid) return;

    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final currentProfile = userProvider.userProfile;

      if (currentProfile == null) {
        throw Exception('Профиль не найден');
      }

      // Convert age to dateOfBirth
      final age = int.parse(_ageController.text);
      final dateOfBirth = _calculateDateOfBirth(age);

      final updatedProfile = UserProfile(
        name: _nameController.text,
        dateOfBirth: dateOfBirth,  // ✅ Use dateOfBirth instead of age
        weight: double.parse(_weightController.text),
        dailyTolerancePhe: double.parse(_pheToleranceController.text),
        email: _emailController.text,
        medicalFormula: _medicalFormulaController.text.isEmpty
            ? null
            : _medicalFormulaController.text,
      );

      await authProvider.updateUserProfile(updatedProfile);
      await userProvider.updateUserProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Профиль успешно обновлен'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать профиль'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Личные данные'),
            Tab(text: 'Медицинские данные'),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveChanges,
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Personal Data Tab
          _buildPersonalDataTab(),
          // Medical Data Tab
          _buildMedicalDataTab(),
        ],
      ),
    );
  }

  Widget _buildPersonalDataTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _personalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Основная информация о вас',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Name
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Имя *',
                hintText: 'Как вас зовут?',
                prefixIcon: Icon(Icons.badge),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите имя';
                }
                if (value.length < 2) {
                  return 'Минимум 2 символа';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Age
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Возраст *',
                hintText: '25',
                prefixIcon: Icon(Icons.cake),
                suffixText: 'лет',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите возраст';
                }
                final age = int.tryParse(value);
                if (age == null || age < 1 || age > 120) {
                  return 'Введите корректный возраст';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Weight - Особое внимание
            TextFormField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
              decoration: InputDecoration(
                labelText: 'Вес *',
                hintText: '70.5',
                prefixIcon: const Icon(Icons.monitor_weight),
                suffixText: 'кг',
                helperText: 'Используется для расчета рекомендаций',
                helperStyle: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите вес';
                }
                final weight = double.tryParse(value);
                if (weight == null || weight < 1 || weight > 300) {
                  return 'Введите корректный вес';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email (read-only)
            TextFormField(
              controller: _emailController,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'example@mail.com',
                prefixIcon: const Icon(Icons.email),
                helperText: 'Email нельзя изменить',
                helperStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalDataTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _medicalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.medical_information, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Данные для контроля диеты при ФКУ',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Phe Tolerance
            TextFormField(
              controller: _pheToleranceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
              decoration: InputDecoration(
                labelText: 'Суточная толерантность Phe *',
                hintText: '600',
                prefixIcon: const Icon(Icons.medical_information),
                suffixText: 'мг',
                helperText: 'Уточните у вашего врача',
                helperMaxLines: 2,
                helperStyle: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите суточную норму';
                }
                final number = double.tryParse(value);
                if (number == null || number <= 0) {
                  return 'Введите корректное значение';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Medical Formula
            TextFormField(
              controller: _medicalFormulaController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Какую смесь пьете?',
                hintText: 'Например: Anamix Junior, PKU Cooler',
                prefixIcon: Icon(Icons.local_drink),
                helperText: 'Необязательное поле',
              ),
            ),
            const SizedBox(height: 24),

            // Info Cards
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade900),
                        const SizedBox(width: 8),
                        Text(
                          'Важно знать',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Суточная толерантность Phe индивидуальна для каждого пациента',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Значение определяется врачом на основе анализов крови',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• При изменении состояния обратитесь к врачу для корректировки',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tips_and_updates,
                            color: Colors.green.shade900),
                        const SizedBox(width: 8),
                        Text(
                          'Рекомендации',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Регулярно проверяйте уровень фенилаланина в крови',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Ведите ежедневный учет потребления Phe в приложении',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Консультируйтесь с диетологом при составлении меню',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}