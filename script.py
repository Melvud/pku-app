import ijson
import csv
import os
import time
from tqdm import tqdm

# ================= НАСТРОЙКИ =================

INPUT_FILES = [
    'FoodData_Central_foundation_food_json_2025-04-24.json',
    'surveyDownload.json',
    'FoodData_Central_sr_legacy_food_json_2018-04.json' 
]

OUTPUT_CSV = 'usda_pku_max_detailed.csv'

# Коды нутриентов
NUTRIENT_MAP = {
    '203': 'protein',       # Белок
    '204': 'fat',
    '205': 'carbs',
    '208': 'energy',
    '508': 'phe'            # Фенилаланин
}

# Коэффициенты (мг Phe на 1 г белка)
COEFFS = {
    'heavy_protein': 50, # Мясо, рыба, яйца, сыр
    'nuts_legumes': 45,  # Орехи и бобовые (разделены по названиям, но коэф одинаковый)
    'dairy': 40,         # Молочное
    'grains_bread': 30,  # Крупы и хлеб (разделены по названиям, но коэф одинаковый)
    'veg_fruit': 25,     # Овощи и фрукты
    'other': 30          # Остальное
}

# =============================================

def get_category_and_coeff(food_desc, category_desc):
    """
    Определяет МАКСИМАЛЬНО ТОЧНУЮ категорию продукта.
    """
    text = (str(food_desc) + " " + str(category_desc)).lower()
    
    # --- 1. ТЯЖЕЛЫЕ БЕЛКИ (Коэф 50) ---
    
    # 1.1 СЫРЫ
    cheese_keys = ['cheese', 'cheddar', 'parmesan', 'mozzarella', 'brie', 'camembert', 'feta', 'gouda', 'provolone', 'swiss', 'ricotta', 'cottage', 'curd']
    if any(k in text for k in cheese_keys): return 'Cheese', COEFFS['heavy_protein']

    # 1.2 ЯЙЦА
    egg_keys = ['egg', 'yolk', 'white', 'omelet']
    if any(k in text for k in egg_keys) and 'eggplant' not in text: return 'Eggs', COEFFS['heavy_protein']

    # 1.3 МЯСО
    meat_keys = ['meat', 'beef', 'pork', 'chicken', 'turkey', 'lamb', 'veal', 'bacon', 'sausage', 'ham', 'steak', 'burger', 'salami', 'poultry', 'frankfurter', 'liver', 'kidney', 'heart']
    if any(k in text for k in meat_keys): return 'Meat', COEFFS['heavy_protein']

    # 1.4 РЫБА
    fish_keys = ['fish', 'salmon', 'tuna', 'cod', 'trout', 'shrimp', 'crab', 'lobster', 'oyster', 'mussel', 'clam', 'sardine', 'anchovy', 'seafood', 'sushi', 'caviar']
    if any(k in text for k in fish_keys): return 'Fish/Seafood', COEFFS['heavy_protein']


    # --- 2. ОРЕХИ И БОБОВЫЕ (Коэф 45) ---

    # 2.1 БОБОВЫЕ (Включая арахис и сою)
    legume_keys = ['bean', 'lentil', 'soy', 'tofu', 'hummus', 'pea ', 'peas', 'chickpea', 'peanut', 'edamame', 'miso']
    if any(k in text for k in legume_keys): return 'Legumes', COEFFS['nuts_legumes']

    # 2.2 ОРЕХИ И СЕМЕНА
    nut_keys = ['nut', 'almond', 'walnut', 'cashew', 'pecan', 'pistachio', 'macadamia', 'hazelnut', 'seeds', 'sunflower', 'pumpkin seed', 'flax', 'chia', 'sesame', 'tahini']
    if any(k in text for k in nut_keys): return 'Nuts/Seeds', COEFFS['nuts_legumes']


    # --- 3. МОЛОЧНОЕ (Коэф 40) ---
    
    dairy_keys = ['milk', 'yogurt', 'cream', 'dairy', 'latte', 'cappuccino', 'buttermilk', 'kefir', 'whey', 'casein', 'ice cream', 'custard', 'pudding']
    if any(k in text for k in dairy_keys):
        if 'coconut' in text or 'almond' in text or 'soy' in text or 'oat' in text:
             return 'Plant Milk', COEFFS['nuts_legumes'] # Растительное молоко ближе к орехам/бобам
        return 'Dairy', COEFFS['dairy']


    # --- 4. ЗЕРНОВЫЕ И ХЛЕБ (Коэф 30) ---

    # 4.1 ХЛЕБ И ВЫПЕЧКА
    bread_keys = [
        'bread', 'toast', 'bagel', 'roll', 'bun', 'croissant', 'muffin', 'pancake', 'waffle', 
        'biscuit', 'cookie', 'cracker', 'cake', 'pie', 'pastry', 'dough', 'pizza', 'sandwich', 
        'brownie', 'donut', 'tortilla', 'pita', 'flatbread'
    ]
    if any(k in text for k in bread_keys): return 'Breads/Bakery', COEFFS['grains_bread']

    # 4.2 КРУПЫ, ПАСТА, МУКА
    grain_keys = [
        'pasta', 'spaghetti', 'macaroni', 'noodle', 'ravioli', 'lasagna', 'vermicelli',
        'rice', 'oat', 'barley', 'rye', 'wheat', 'buckwheat', 'quinoa', 'millet', 'bulgur', 'couscous', 'cornmeal',
        'cereal', 'granola', 'flour', 'semolina', 'bran', 'germ', 'starch'
    ]
    if any(k in text for k in grain_keys): return 'Grains/Pasta', COEFFS['grains_bread']


    # --- 5. ОВОЩИ И ФРУКТЫ (Коэф 25) ---

    # 5.1 ОВОЩИ
    veg_keys = ['vegetable', 'potato', 'tomato', 'carrot', 'onion', 'corn', 'cucumber', 'lettuce', 'spinach', 'broccoli', 'cabbage', 'cauliflower', 'pepper', 'mushroom', 'squash', 'zucchini', 'salad', 'soup', 'stew', 'garlic', 'celery', 'asparagus', 'kale', 'avocado', 'olive']
    if any(k in text for k in veg_keys): return 'Vegetables', COEFFS['veg_fruit']

    # 5.2 ФРУКТЫ
    fruit_keys = ['fruit', 'apple', 'banana', 'orange', 'juice', 'berry', 'grape', 'pear', 'peach', 'apricot', 'plum', 'melon', 'watermelon', 'pineapple', 'mango', 'kiwi', 'lemon', 'lime', 'cherry', 'strawberry', 'raspberry', 'blueberry', 'raisin', 'date', 'fig', 'prune']
    if any(k in text for k in fruit_keys): return 'Fruits', COEFFS['veg_fruit']


    # --- 6. ОСТАЛЬНОЕ ---

    # 6.1 СЛАДОСТИ
    sweet_keys = ['chocolate', 'candy', 'sugar', 'honey', 'syrup', 'jam', 'jelly', 'marmalade', 'gum', 'cocoa']
    if any(k in text for k in sweet_keys): return 'Sweets', COEFFS['other']
        
    # 6.2 НАПИТКИ
    bev_keys = ['water', 'tea', 'coffee', 'soda', 'cola', 'beer', 'wine', 'alcohol', 'liquor', 'drink', 'beverage', 'lemonade']
    if any(k in text for k in bev_keys): return 'Beverages', 0 

    return 'Other', COEFFS['other']

# Вспомогательные функции те же...
def get_safe_float(val):
    if val is None: return 0.0
    try: return float(val)
    except: return 0.0

def detect_json_prefix(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            start = f.read(2048)
            if '"FoundationFoods"' in start: return "FoundationFoods.item"
            if '"SurveyFoods"' in start: return "SurveyFoods.item"
            if '"SRLegacyFoods"' in start: return "SRLegacyFoods.item"
    except: pass
    return "item"

def process_max_detailed():
    print(f"--- ЗАПУСК МАКСИМАЛЬНО ДЕТАЛЬНОЙ КЛАССИФИКАЦИИ ---")
    start_time = time.time()
    total_saved = 0
    
    with open(OUTPUT_CSV, 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = ['fdc_id', 'name', 'category', 'protein', 'phe', 'phe_source', 'fat', 'carbs', 'energy']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()

        for file_path in INPUT_FILES:
            if not os.path.exists(file_path):
                print(f"❌ Файл не найден: {file_path}")
                continue
            
            print(f"\nОбработка: {file_path}")
            prefix = detect_json_prefix(file_path)

            try:
                with open(file_path, 'rb') as f:
                    foods = ijson.items(f, prefix)
                    for food in tqdm(foods, desc="Анализ", unit=" rows"):
                        
                        fdc_id = food.get('fdcId')
                        desc = food.get('description', '')
                        if not fdc_id: continue

                        usda_cat = ""
                        if 'foodCategory' in food and isinstance(food['foodCategory'], dict):
                            usda_cat = food['foodCategory'].get('description', '')
                        elif 'wweiaFoodCategory' in food and isinstance(food['wweiaFoodCategory'], dict):
                            usda_cat = food['wweiaFoodCategory'].get('wweiaFoodCategoryDescription', '')
                        
                        pku_category, pku_coeff = get_category_and_coeff(desc, usda_cat)

                        nutrients = {k: 0.0 for k in NUTRIENT_MAP.values()}
                        raw_nutrients = food.get('foodNutrients', [])
                        
                        for n in raw_nutrients:
                            nid = None
                            if 'nutrient' in n: nid = n['nutrient'].get('number')
                            elif 'nutrientNumber' in n: nid = n.get('nutrientNumber')
                            
                            if nid and str(nid) in NUTRIENT_MAP:
                                key = NUTRIENT_MAP[str(nid)]
                                nutrients[key] = get_safe_float(n.get('amount'))

                        protein = nutrients['protein']
                        original_phe = nutrients['phe']
                        
                        final_phe = 0.0
                        source = 'empty'

                        if original_phe > 0:
                            final_phe = original_phe * 1000.0
                            source = 'original'
                        elif protein > 0:
                            final_phe = protein * pku_coeff
                            source = 'calculated'
                        
                        row = {
                            'fdc_id': fdc_id,
                            'name': desc,
                            'category': pku_category,
                            'protein': round(protein, 2),
                            'phe': round(final_phe, 1),
                            'phe_source': source,
                            'fat': round(nutrients['fat'], 2),
                            'carbs': round(nutrients['carbs'], 2),
                            'energy': round(nutrients['energy'], 0)
                        }
                        writer.writerow(row)
                        total_saved += 1
                        
            except Exception as e:
                print(f"💀 Ошибка в файле {file_path}: {e}")

    print(f"\n✅ ГОТОВО! Обработано {total_saved} продуктов.")
    print(f"Файл: {OUTPUT_CSV}")

if __name__ == "__main__":
    process_max_detailed()