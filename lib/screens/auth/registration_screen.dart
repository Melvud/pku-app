import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../main.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _pheToleranceController = TextEditingController();
  final _customFormulaController = TextEditingController();
  
  DateTime? _selectedDateOfBirth;
  String _selectedFormula = 'PKU Anamix';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  int _currentStep = 0;

  // Список популярных лечебных смесей
  final List<String> _formulas = [
    'PKU Anamix',
    'PKU Anamix Junior',
    'Lophlex LQ',
    'PKU Cooler',
    'PKU Express',
    'PKU Air',
    'PKU Sphere',
    'Другая',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _weightController.dispose();
    _pheToleranceController.dispose();
    _customFormulaController.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _step1FormKey.currentState?.validate() ?? false;
      case 1:
        return _step2FormKey.currentState?.validate() ?? false;
      case 2:
        return _step3FormKey.currentState?.validate() ?? false;
      default:
        return false;
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ru'),
      helpText: 'Выберите дату рождения',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    
    if (picked != null) {
      setState(() => _selectedDateOfBirth = picked);
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _handleRegistration() async {
    if (!_validateCurrentStep()) return;

    if (_selectedDateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите дату рождения'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final medicalFormula = _selectedFormula == 'Другая' 
        ? _customFormulaController.text 
        : _selectedFormula;

    final profile = UserProfile(
      name: _nameController.text,
      dateOfBirth: _selectedDateOfBirth!,
      weight: double.parse(_weightController.text),
      dailyTolerancePhe: double.parse(_pheToleranceController.text),
      email: _emailController.text,
      medicalFormula: medicalFormula.isEmpty ? null : medicalFormula,
    );

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    
    final error = await authProvider.register(
      email: _emailController.text,
      password: _passwordController.text,
      profile: profile,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (error == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MainNavigationScreen(),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_validateCurrentStep()) {
              if (_currentStep < 2) {
                setState(() => _currentStep++);
              } else {
                _handleRegistration();
              }
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            }
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading ? null : details.onStepContinue,
                      child: _isLoading && _currentStep == 2
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _currentStep == 2 ? 'Завершить' : 'Далее',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : details.onStepCancel,
                        child: const Text(
                          'Назад',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            // Step 1: Account Info
            Step(
              title: const Text(
                'Данные аккаунта',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: Form(
                key: _step1FormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'example@mail.com',
                        prefixIcon: Icon(Icons.email_outlined),
                        helperText: 'Обязательное поле',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите email';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Введите корректный email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        hintText: 'Минимум 6 символов',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        helperText: 'Обязательное поле',
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите пароль';
                        }
                        if (value.length < 6) {
                          return 'Минимум 6 символов';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Подтвердите пароль',
                        hintText: 'Повторите пароль',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        helperText: 'Обязательное поле',
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Подтвердите пароль';
                        }
                        if (value != _passwordController.text) {
                          return 'Пароли не совпадают';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Step 2: Personal Info
            Step(
              title: const Text(
                'Личные данные',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: Form(
                key: _step2FormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Имя',
                        hintText: 'Иван',
                        prefixIcon: Icon(Icons.person_outlined),
                        helperText: 'Обязательное поле',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите имя';
                        }
                        if (value.length < 2) {
                          return 'Минимум 2 символа';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Дата рождения
                    InkWell(
                      onTap: _selectDateOfBirth,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Дата рождения *',
                          prefixIcon: Icon(Icons.cake_outlined),
                          helperText: 'Обязательное поле',
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDateOfBirth == null
                                  ? 'Выберите дату'
                                  : DateFormat('dd.MM.yyyy').format(_selectedDateOfBirth!),
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedDateOfBirth == null
                                    ? Colors.grey.shade600
                                    : null,
                              ),
                            ),
                            if (_selectedDateOfBirth != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_calculateAge(_selectedDateOfBirth!)} лет',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _weightController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Вес',
                        hintText: '70.5',
                        prefixIcon: Icon(Icons.monitor_weight_outlined),
                        suffixText: 'кг',
                        helperText: 'Обязательное поле',
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
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Step 3: Medical Info
            Step(
              title: const Text(
                'Медицинские данные',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              isActive: _currentStep >= 2,
              content: Form(
                key: _step3FormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      margin: const EdgeInsets.only(bottom: 16, top: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Уточните суточную норму у вашего врача',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextFormField(
                      controller: _pheToleranceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Суточная толерантность Phe',
                        hintText: '600',
                        prefixIcon: Icon(Icons.medical_information_outlined),
                        suffixText: 'мг',
                        helperText: 'Обязательное поле',
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
                    const SizedBox(height: 16),
                    
                    // Выбор лечебной смеси
                    DropdownButtonFormField<String>(
                      value: _selectedFormula,
                      decoration: const InputDecoration(
                        labelText: 'Какую смесь пьете?',
                        prefixIcon: Icon(Icons.local_drink_outlined),
                        helperText: 'Необязательное поле',
                      ),
                      items: _formulas.map((formula) {
                        return DropdownMenuItem(
                          value: formula,
                          child: Text(formula),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedFormula = value!);
                      },
                    ),
                    
                    // Поле для своей смеси если выбрано "Другая"
                    if (_selectedFormula == 'Другая') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _customFormulaController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Название смеси',
                          hintText: 'Введите название',
                          prefixIcon: Icon(Icons.edit_outlined),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
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