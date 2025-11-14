import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Справка'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HelpCard(
            title: 'Что такое фенилкетонурия?',
            icon: Icons.info_outline,
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const _PKUInfoScreen(),
              ),
            ),
          ),
          _HelpCard(
            title: 'Диета при ФКУ',
            icon: Icons.restaurant_menu,
            color: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const _PKUDietScreen(),
              ),
            ),
          ),
          _HelpCard(
            title: 'Лечебные смеси',
            icon: Icons.medical_services,
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const _MedicalFormulasScreen(),
              ),
            ),
          ),
          _HelpCard(
            title: 'Как пользоваться приложением',
            icon: Icons.help_outline,
            color: Colors.purple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const _AppGuideScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HelpCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// PKU Info Screen
class _PKUInfoScreen extends StatelessWidget {
  const _PKUInfoScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Что такое ФКУ?'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Основная информация'),
            _Paragraph(
              'Фенилкетонурия (ФКУ) — это наследственное заболевание, связанное с нарушением обмена аминокислоты фенилаланина. При ФКУ в организме не хватает или полностью отсутствует фермент фенилаланингидроксилаза, который превращает фенилаланин в тирозин.',
            ),
            _Paragraph(
              'В результате фенилаланин накапливается в крови и тканях организма, что может привести к повреждению центральной нервной системы и нарушению умственного развития, если не соблюдать специальную диету.',
            ),
            const SizedBox(height: 24),
            _SectionTitle('Причины заболевания'),
            _Paragraph(
              'ФКУ является генетическим заболеванием и передается по аутосомно-рецессивному типу. Это означает, что:',
            ),
            _BulletPoint('Ребенок получает два дефектных гена (по одному от каждого родителя)'),
            _BulletPoint(
                'Родители обычно являются носителями и сами не болеют'),
            _BulletPoint('Вероятность рождения больного ребенка у двух носителей — 25%'),
            const SizedBox(height: 24),
            _SectionTitle('Симптомы'),
            _Paragraph(
              'При отсутствии лечения ФКУ может проявляться следующими симптомами:',
            ),
            _BulletPoint('Задержка психомоторного и умственного развития'),
            _BulletPoint('Судороги и эпилептические припадки'),
            _BulletPoint('Повышенная возбудимость и гиперактивность'),
            _BulletPoint('Экзема и другие кожные проявления'),
            _BulletPoint('Светлая кожа, волосы и глаза (из-за недостатка меланина)'),
            _BulletPoint('Характерный "мышиный" запах от тела и мочи'),
            const SizedBox(height: 24),
            _SectionTitle('Диагностика'),
            _Paragraph(
              'В большинстве стран, включая Россию, проводится массовый скрининг новорожденных на ФКУ. Анализ крови берется на 4-5 день жизни ребенка.',
            ),
            _Paragraph(
              'Если уровень фенилаланина в крови повышен, проводится дополнительное обследование для подтверждения диагноза.',
            ),
            const SizedBox(height: 24),
            _SectionTitle('Лечение'),
            _Paragraph(
              'Основной метод лечения ФКУ — это пожизненная низкобелковая диета с ограничением фенилаланина. При раннем начале лечения (в первые недели жизни) и строгом соблюдении диеты дети развиваются нормально.',
            ),
            _Paragraph(
              'Важно регулярно контролировать уровень фенилаланина в крови и корректировать диету под наблюдением врача и диетолога.',
            ),
            const SizedBox(height: 24),
            _InfoBox(
              icon: Icons.emergency,
              title: 'Важно!',
              text:
                  'Раннее выявление и своевременное начало лечения позволяют предотвратить развитие тяжелых осложнений и обеспечить нормальное развитие ребенка.',
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}

// PKU Diet Screen
class _PKUDietScreen extends StatelessWidget {
  const _PKUDietScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Диета при ФКУ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Основные принципы диеты'),
            _Paragraph(
              'Диета при ФКУ — это основа лечения заболевания. Главная цель диеты — ограничить поступление фенилаланина с пищей до безопасного уровня, который определяется индивидуально для каждого пациента.',
            ),
            const SizedBox(height: 24),
            _SectionTitle('Запрещенные продукты'),
            _Paragraph('Необходимо полностью исключить из рациона:'),
            _BulletPoint('Мясо, птицу, рыбу и морепродукты'),
            _BulletPoint('Яйца'),
            _BulletPoint('Молоко и молочные продукты (сыр, творог, йогурт)'),
            _BulletPoint('Бобовые (горох, фасоль, чечевица, соя)'),
            _BulletPoint('Орехи и семечки'),
            _BulletPoint('Обычный хлеб и выпечку'),
            _BulletPoint('Обычные макаронные изделия'),
            const SizedBox(height: 24),
            _SectionTitle('Ограниченно разрешенные продукты'),
            _Paragraph(
                'Эти продукты можно употреблять в строго контролируемых количествах:'),
            _BulletPoint('Картофель'),
            _BulletPoint('Некоторые овощи (капуста, свекла, морковь)'),
            _BulletPoint('Некоторые крупы в ограниченном количестве'),
            const SizedBox(height: 24),
            _SectionTitle('Разрешенные продукты'),
            _Paragraph('Без ограничений можно употреблять:'),
            _BulletPoint('Большинство фруктов и ягод'),
            _BulletPoint('Овощи с низким содержанием белка (огурцы, помидоры, кабачки)'),
            _BulletPoint('Растительные масла'),
            _BulletPoint('Сахар, мед, варенье'),
            _BulletPoint('Специальные низкобелковые продукты'),
            const SizedBox(height: 24),
            _SectionTitle('Специальные низкобелковые продукты'),
            _Paragraph(
              'Для обеспечения полноценного питания разработаны специальные продукты с пониженным содержанием белка:',
            ),
            _BulletPoint('Низкобелковый хлеб'),
            _BulletPoint('Низкобелковые макароны'),
            _BulletPoint('Низкобелковая мука'),
            _BulletPoint('Специальные кондитерские изделия'),
            const SizedBox(height: 24),
            _SectionTitle('Расчет рациона'),
            _Paragraph(
              'Суточная норма фенилаланина рассчитывается индивидуально врачом и зависит от:',
            ),
            _BulletPoint('Возраста пациента'),
            _BulletPoint('Веса'),
            _BulletPoint('Результатов анализов крови'),
            _BulletPoint('Физической активности'),
            const SizedBox(height: 24),
            _InfoBox(
              icon: Icons.calculate,
              title: 'Используйте приложение!',
              text:
                  'PheTracker помогает вести учет потребленного фенилаланина и контролировать соблюдение диеты. Регулярно вносите данные о съеденных продуктах.',
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            _InfoBox(
              icon: Icons.medical_information,
              title: 'Важно!',
              text:
                  'Диета при ФКУ должна соблюдаться пожизненно! Даже у взрослых пациентов нарушение диеты может привести к неврологическим проблемам.',
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}

// Medical Formulas Screen
class _MedicalFormulasScreen extends StatelessWidget {
  const _MedicalFormulasScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Лечебные смеси'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Зачем нужны лечебные смеси?'),
            _Paragraph(
              'При ФКУ из рациона исключаются продукты, богатые белком. Однако белок необходим организму для роста, развития и нормального функционирования. Лечебные смеси — это специальные продукты, которые содержат все необходимые аминокислоты, кроме фенилаланина.',
            ),
            const SizedBox(height: 24),
            _SectionTitle('Состав лечебных смесей'),
            _Paragraph('Современные лечебные смеси для пациентов с ФКУ содержат:'),
            _BulletPoint('Аминокислоты (кроме фенилаланина)'),
            _BulletPoint('Витамины и минералы'),
            _BulletPoint('Микроэлементы'),
            _BulletPoint('Иногда — углеводы и жиры'),
            const SizedBox(height: 24),
            _SectionTitle('Виды лечебных смесей'),
            _Paragraph('Лечебные смеси различаются по возрасту и форме выпуска:'),
            const SizedBox(height: 16),
            _FormulaCard(
              title: 'Для младенцев (0-12 месяцев)',
              examples: 'PKU Anamix Infant, Lophlex LQ Juicy',
              description:
                  'Адаптированные смеси, которые можно использовать с рождения. Содержат все необходимые питательные вещества для грудных детей.',
            ),
            _FormulaCard(
              title: 'Для детей (1-10 лет)',
              examples: 'PKU Anamix Junior, PKU Cooler',
              description:
                  'Смеси с приятным вкусом, часто в виде напитков. Адаптированы под потребности растущего организма.',
            ),
            _FormulaCard(
              title: 'Для подростков и взрослых',
              examples: 'Lophlex LQ, PKU Express',
              description:
                  'Концентрированные смеси с разными вкусами. Удобны в использовании и транспортировке.',
            ),
            _FormulaCard(
              title: 'Специальные формы',
              examples: 'PKU Air, PKU Sphere',
              description:
                  'Инновационные формы выпуска: батончики, таблетки, порошки. Удобны для людей с активным образом жизни.',
            ),
            const SizedBox(height: 24),
            _SectionTitle('Как принимать лечебную смесь'),
            _BulletPoint('Суточная доза определяется врачом индивидуально'),
            _BulletPoint('Обычно прием разделяют на 2-3 раза в день'),
            _BulletPoint('Лучше принимать во время еды или сразу после'),
            _BulletPoint('Порошковые смеси разводят водой или соком'),
            _BulletPoint('Готовые жидкие смеси можно пить сразу'),
            const SizedBox(height: 24),
            _SectionTitle('Получение лечебных смесей'),
            _Paragraph(
              'В России лечебные смеси для пациентов с ФКУ предоставляются бесплатно по программе обеспечения редкими лекарственными препаратами. Для получения смеси необходимо:',
            ),
            _BulletPoint('Иметь подтвержденный диагноз ФКУ'),
            _BulletPoint('Состоять на учете у генетика'),
            _BulletPoint('Получить рецепт от лечащего врача'),
            _BulletPoint('Обратиться в региональный центр обеспечения'),
            const SizedBox(height: 24),
            _InfoBox(
              icon: Icons.favorite,
              title: 'Совет',
              text:
                  'Если смесь имеет неприятный вкус, попробуйте смешивать ее с разрешенными соками, добавлять в низкобелковую выпечку или замораживать в виде мороженого.',
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            _InfoBox(
              icon: Icons.warning,
              title: 'Внимание!',
              text:
                  'Нельзя самостоятельно менять дозировку или отказываться от приема лечебной смеси без консультации с врачом!',
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

// App Guide Screen
class _AppGuideScreen extends StatelessWidget {
  const _AppGuideScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Как пользоваться'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Добро пожаловать в PheTracker!'),
            _Paragraph(
              'PheTracker — это ваш персональный помощник в соблюдении диеты при фенилкетонурии. Приложение поможет контролировать потребление фенилаланина и вести здоровый образ жизни.',
            ),
            const SizedBox(height: 24),
            _SectionTitle('Дневник питания'),
            _Paragraph(
              'Главный экран приложения — это ваш дневник питания. Здесь вы видите:',
            ),
            _BulletPoint('Текущую дату (можно переключать между днями)'),
            _BulletPoint('Общую статистику по фенилаланину и нутриентам'),
            _BulletPoint('Приемы пищи (завтрак, обед, ужин и др.)'),
            const SizedBox(height: 16),
            _GuideCard(
              icon: Icons.add_circle,
              title: 'Добавление продуктов',
              steps: [
                'Нажмите на кнопку "+" в нужном приеме пищи',
                'Выберите один из способов добавления:',
                '  • Поиск в базе продуктов',
                '  • Сканирование QR-кода',
                '  • Ручной ввод данных',
                'Укажите размер порции',
                'Нажмите "Добавить в дневник"',
              ],
            ),
            _GuideCard(
              icon: Icons.edit,
              title: 'Управление приемами пищи',
              steps: [
                'Можно добавить свои приемы пищи',
                'Установить время для каждого приема',
                'Удалить ненужные приемы',
                'Все записи можно редактировать',
              ],
            ),
            const SizedBox(height: 24),
            _SectionTitle('База продуктов'),
            _Paragraph(
              'В приложении есть большая база продуктов с данными о содержании фенилаланина:',
            ),
            _BulletPoint('Поиск по названию'),
            _BulletPoint('Фильтр по категориям'),
            _BulletPoint('Автоматическая синхронизация данных'),
            _BulletPoint('Можно добавлять свои продукты'),
            const SizedBox(height: 24),
            _SectionTitle('Сканирование штрих-кодов'),
            _Paragraph(
              'Быстрый способ найти продукт:',
            ),
            _BulletPoint('Нажмите на иконку QR-сканера'),
            _BulletPoint('Наведите камеру на штрих-код'),
            _BulletPoint('Приложение найдет продукт в базах данных'),
            _BulletPoint('Если продукт не найден — можно добавить вручную'),
            const SizedBox(height: 24),
            _SectionTitle('Статистика'),
            _Paragraph(
              'В разделе статистики вы можете:',
            ),
            _BulletPoint('Просматривать данные по месяцам'),
            _BulletPoint('Анализировать динамику потребления Phe'),
            _BulletPoint('Видеть распределение нутриентов'),
            _BulletPoint('Экспортировать отчеты в PDF или Excel'),
            const SizedBox(height: 24),
            _SectionTitle('Настройки профиля'),
            _Paragraph(
              'В настройках вы можете:',
            ),
            _BulletPoint('Изменить личные данные (имя, возраст, вес)'),
            _BulletPoint('Обновить суточную норму фенилаланина'),
            _BulletPoint('Указать используемую лечебную смесь'),
            _BulletPoint('Настроить уведомления'),
            const SizedBox(height: 24),
            _InfoBox(
              icon: Icons.lightbulb,
              title: 'Совет',
              text:
                  'Регулярно обновляйте свой вес в настройках — это важно для точных расчетов и рекомендаций!',
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            _InfoBox(
              icon: Icons.phone,
              title: 'Нужна помощь?',
              text:
                  'Если у вас возникли вопросы или предложения, свяжитесь с нами через раздел "О приложении".',
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable Widgets
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String text;
  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, height: 1.5),
        textAlign: TextAlign.justify,
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 18, height: 1.5)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color color;

  const _InfoBox({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormulaCard extends StatelessWidget {
  final String title;
  final String examples;
  final String description;

  const _FormulaCard({
    required this.title,
    required this.examples,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Примеры: $examples',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> steps;

  const _GuideCard({
    required this.icon,
    required this.title,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...steps.map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    step,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}