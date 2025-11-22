import pandas as pd
from deep_translator import GoogleTranslator
from tqdm import tqdm
import time
import os

# ================= НАСТРОЙКИ =================

INPUT_FILE = 'usda_pku_max_detailed.csv'
OUTPUT_FILE = 'usda_pku_russian_direct.csv'

# Словарь категорий
CATEGORY_MAP = {
    'Cheese': 'Сыры',
    'Eggs': 'Яйца',
    'Meat': 'Мясо',
    'Fish/Seafood': 'Рыба и морепродукты',
    'Legumes': 'Бобовые',
    'Nuts/Seeds': 'Орехи и семена',
    'Dairy': 'Молочные продукты',
    'Plant Milk': 'Растительное молоко',
    'Breads/Bakery': 'Хлеб и выпечка',
    'Grains/Pasta': 'Крупы и макароны',
    'Vegetables': 'Овощи',
    'Fruits': 'Фрукты',
    'Sweets': 'Сладости',
    'Beverages': 'Напитки',
    'Other': 'Другое'
}

NUMERIC_COLS = ['protein', 'phe', 'fat', 'carbs', 'energy']

# =============================================

def translate_with_retry(text, translator, max_retries=3):
    """Перевод с защитой от сбоев"""
    for i in range(max_retries):
        try:
            return translator.translate(text)
        except Exception:
            if i == max_retries - 1:
                return text 
            time.sleep(1)
    return text

def main():
    print("--- ЗАПУСК ПРЯМОГО ПЕРЕВОДА (БЕЗ НОРМАЛИЗАЦИИ) ---")
    
    if not os.path.exists(INPUT_FILE):
        print(f"❌ Файл {INPUT_FILE} не найден!")
        return

    print("Чтение файла...")
    df = pd.read_csv(INPUT_FILE)
    print(f"Всего продуктов: {len(df)}")

    translator = GoogleTranslator(source='auto', target='ru')
    translation_cache = {}

    # 1. Перевод категорий
    print("Перевод категорий...")
    df['category_ru'] = df['category'].map(CATEGORY_MAP).fillna('Другое')

    # 2. Перевод названий
    tqdm.pandas(desc="Перевод названий")

    def process_row(name_en):
        if pd.isna(name_en) or name_en == "":
            return ""
            
        # ПРОВЕРКА КЭША
        if name_en in translation_cache:
            return translation_cache[name_en]
        
        # ПЕРЕВОД "КАК ЕСТЬ"
        try:
            ru_text = translate_with_retry(name_en, translator)
            # Делаем первую букву заглавной для красоты
            if ru_text:
                ru_text = ru_text[0].upper() + ru_text[1:]
            
            translation_cache[name_en] = ru_text
            return ru_text
        except:
            return name_en

    df['name_ru'] = df['name'].progress_apply(process_row)

    # 3. Форматирование чисел (точка -> запятая)
    print("Форматирование чисел...")
    for col in NUMERIC_COLS:
        if col in df.columns:
            # Phe и Energy - 1 знак, остальные - 2
            decimals = 1 if col in ['phe', 'energy'] else 2
            
            df[col] = df[col].apply(
                lambda x: f"{x:.{decimals}f}".replace('.', ',') if pd.notnull(x) and x != "" else "0,0"
            )

    # 4. Сборка финальной таблицы
    final_df = df[[
        'fdc_id', 
        'name_ru',      # Русское название
        'category_ru',  # Русская категория
        'protein', 
        'phe', 
        'phe_source', 
        'fat', 
        'carbs', 
        'energy'
    ]]

    # Переименовываем для удобства
    final_df.columns = [
        'fdc_id', 'name', 'category', 'protein', 'phe', 'phe_source', 'fat', 'carbs', 'energy'
    ]

    print(f"Сохранение в {OUTPUT_FILE}...")
    final_df.to_csv(OUTPUT_FILE, index=False, sep=';', encoding='utf-8-sig')
    
    print("ГОТОВО! ✅")
    print(f"Файл: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()