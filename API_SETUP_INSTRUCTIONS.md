# Инструкции по настройке API для интеграции с FatSecret и USDA

## Обзор

Проект интегрирован с двумя мощными API для получения данных о пищевой ценности продуктов:

1. **FatSecret Platform API** - для сканирования штрих-кодов и получения детальной пищевой ценности
2. **USDA FoodData Central** - для доступа к обширной базе данных продуктов США

## 1. Настройка FatSecret Platform API

### Получение API ключей

1. Перейдите на [FatSecret Platform](https://platform.fatsecret.com/api/)
2. Зарегистрируйтесь или войдите в аккаунт
3. Создайте новое приложение
4. Получите **Client ID** и **Client Secret**

### Настройка в приложении

1. Откройте файл `lib/services/fatsecret_service.dart`
2. Замените следующие константы:

```dart
static const String _clientId = 'YOUR_FATSECRET_CLIENT_ID';
static const String _clientSecret = 'YOUR_FATSECRET_CLIENT_SECRET';
```

### Возможности FatSecret API

- Поиск продуктов по штрих-кодам (UPC/EAN)
- Детальная информация о пищевой ценности
- Поиск продуктов по названию
- Информация о порциях и способах приготовления

### Лимиты

- **Бесплатный план**: 1000 запросов в день
- **Платные планы**: от $99/месяц для неограниченных запросов

---

## 2. Настройка USDA FoodData Central API

### Получение API ключа

1. Перейдите на [USDA FoodData Central API Key Signup](https://fdc.nal.usda.gov/api-key-signup.html)
2. Заполните форму регистрации
3. Получите бесплатный API ключ по email

### Настройка в приложении

1. Откройте файл `lib/services/usda_service.dart`
2. Замените константу:

```dart
static const String _apiKey = 'YOUR_USDA_API_KEY';
```

### Возможности USDA API

- Поиск по названию продукта
- Поиск по штрих-коду (для брендированных продуктов)
- Детальная информация о питательных веществах
- Доступ к нескольким типам данных:
  - **Branded** - брендированные продукты
  - **SR Legacy** - стандартная справочная база
  - **Foundation** - базовые продукты

### Лимиты

- **Бесплатный план**: 1000 запросов в час
- **Без ограничений по дневным запросам**

---

## 3. Синхронизация с Google Sheets

### Текущая настройка

Google Sheet уже настроен для чтения данных:
- **Spreadsheet ID**: `1tDEp7KYh0leLhv_AjpkAFKnq-i2_d39Zx3sco1zVlp4`
- **API Key**: Уже настроен в `lib/services/google_sheets_service.dart`

### Настройка синхронизации USDA → Google Sheets

Для записи данных из USDA в Google Sheets необходимо настроить Google Apps Script:

#### Шаг 1: Создание Apps Script

1. Откройте вашу таблицу: https://docs.google.com/spreadsheets/d/1tDEp7KYh0leLhv_AjpkAFKnq-i2_d39Zx3sco1zVlp4
2. Перейдите в **Extensions > Apps Script**
3. Вставьте следующий код:

```javascript
function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);

    if (data.action === 'sync_usda') {
      const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();

      // Очищаем старые данные (кроме заголовков)
      const lastRow = sheet.getLastRow();
      if (lastRow > 1) {
        sheet.deleteRows(2, lastRow - 1);
      }

      // Вставляем новые данные
      if (data.data && data.data.length > 0) {
        sheet.getRange(2, 1, data.data.length, data.data[0].length).setValues(data.data);
      }

      return ContentService
        .createTextOutput(JSON.stringify({ success: true, rows: data.data.length }))
        .setMimeType(ContentService.MimeType.JSON);
    }

    return ContentService
      .createTextOutput(JSON.stringify({ success: false, error: 'Unknown action' }))
      .setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    return ContentService
      .createTextOutput(JSON.stringify({ success: false, error: error.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}
```

#### Шаг 2: Развертывание Web App

1. Нажмите **Deploy > New deployment**
2. Выберите тип: **Web app**
3. Настройки:
   - **Execute as**: Me
   - **Who has access**: Anyone
4. Нажмите **Deploy**
5. Скопируйте **Web app URL**

#### Шаг 3: Использование в приложении

```dart
final syncService = USDASyncService();

// Синхронизация с использованием Web App
await syncService.syncToGoogleSheets(
  maxProducts: 1000,
  webAppUrl: 'YOUR_WEB_APP_URL_HERE',
);
```

---

## 4. Структура данных в Google Sheets

Таблица должна иметь следующие столбцы:

| A | B | C | D | E | F | G | H | I | J | K |
|---|---|---|---|---|---|---|---|---|---|---|
| Название | Категория | Белок (г/100г) | Phe измеренный | Phe расчетный | Жиры | Углеводы | Калории | Примечания | Источник | Штрих-код |

---

## 5. Использование в коде

### Сканирование штрих-кода

Система автоматически использует все доступные API в следующем порядке:

1. FatSecret Platform API
2. USDA FoodData Central
3. Open Food Facts
4. UPCitemdb

```dart
final barcodeService = MultiSourceBarcodeService();
final result = await barcodeService.searchProductByBarcode('1234567890123');

if (result.hasNutritionData) {
  print('Найден продукт: ${result.product.name}');
  print('Источник: ${result.source}');
}
```

### Поиск продуктов

```dart
// FatSecret
final fatSecretService = FatSecretService();
final fatSecretProducts = await fatSecretService.searchProducts('apple');

// USDA
final usdaService = USDAService();
final usdaProducts = await usdaService.searchProducts('apple');
```

### Синхронизация с Google Sheets

```dart
final syncService = USDASyncService();

// Проверка необходимости синхронизации
if (await syncService.shouldSync()) {
  await syncService.syncToGoogleSheets(
    maxProducts: 1000,
    webAppUrl: 'YOUR_WEB_APP_URL',
  );
}
```

---

## 6. Безопасность

### Рекомендации

1. **НЕ** храните API ключи в публичных репозиториях
2. Используйте `.env` файлы или Flutter secure storage для хранения ключей
3. Для production используйте backend API для прокси запросов

### Пример безопасного хранения

```dart
// Использование flutter_dotenv
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SecureConfig {
  static String get fatSecretClientId => dotenv.env['FATSECRET_CLIENT_ID'] ?? '';
  static String get fatSecretClientSecret => dotenv.env['FATSECRET_CLIENT_SECRET'] ?? '';
  static String get usdaApiKey => dotenv.env['USDA_API_KEY'] ?? '';
}
```

---

## 7. Тестирование

### Проверка интеграции FatSecret

```bash
# Запустите приложение
flutter run

# Отсканируйте штрих-код или введите: 00073390000161
# Это Coca-Cola - должен найтись в FatSecret
```

### Проверка интеграции USDA

```bash
# Поиск продукта "apple" в USDA
# Должно вернуть список яблок из базы данных USDA
```

### Проверка синхронизации Google Sheets

```bash
# Запустите синхронизацию
# Проверьте, что данные появились в Google Sheet
```

---

## 8. Troubleshooting

### FatSecret возвращает ошибку 401

- Проверьте правильность Client ID и Client Secret
- Убедитесь, что приложение активно на платформе FatSecret

### USDA возвращает ошибку 403

- Проверьте API ключ
- Убедитесь, что не превышен лимит запросов (1000/час)

### Google Sheets не обновляется

- Проверьте, что Web App развернут корректно
- Убедитесь, что доступ установлен как "Anyone"
- Проверьте URL Web App

---

## 9. Дополнительные ресурсы

- [FatSecret API Documentation](https://platform.fatsecret.com/api/Default.aspx?screen=rapiref2)
- [USDA FoodData Central API Guide](https://fdc.nal.usda.gov/api-guide.html)
- [Google Apps Script Documentation](https://developers.google.com/apps-script)

---

## 10. Контакты для поддержки

При возникновении проблем:
1. Проверьте логи в консоли Flutter
2. Убедитесь, что все API ключи настроены правильно
3. Проверьте интернет-соединение

Удачной интеграции!
