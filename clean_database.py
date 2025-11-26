import pandas as pd
import re
import sys

# Input/Output files
INPUT_FILE = 'usda_pku_russian_direct.csv'
OUTPUT_FILE = 'usda_pku_russian_cleaned.csv'

# Patterns to DROP the row entirely (Recipes, Composite Dishes)
PATTERNS_TO_DROP_ROW = [
    r'\bсэндвич\b',
    r'\bбургер\b',
    r'\bчизбургер\b',
    r'\bгамбургер\b',
    r'\bхот-дог\b',
    r'\bпицца\b',
    r'\bбуррито\b',
    r'\bтако\b',
    r'\bэнчилада\b',
    r'\bкесадилья\b',
    r'\bначос\b',
    r'\bлазанья\b',
    r'\bпаста с\b', # Pasta with...
    r'\bмакароны с\b', # Macaroni with...
    r'\bспагетти с\b', # Spaghetti with...
    r'\bрис с\b', # Rice with...
    r'\bплов\b',
    r'\bризотто\b',
    r'\bпаэлья\b',
    r'\bрагу\b',
    r'\bгуляш\b',
    r'\bбефстроганов\b',
    r'\bжаркое\b',
    r'\bзапеканка\b',
    r'\bомлет\b',
    r'\bяичница\b',
    r'\bсуп\b',
    r'\bбульон\b',
    r'\bборщ\b',
    r'\bщи\b',
    r'\bсолянка\b',
    r'\bрассольник\b',
    r'\bуха\b',
    r'\bокрошка\b',
    r'\bсалат\b', # Salad (usually composite)
    r'\bвинегрет\b',
    r'\bоливье\b',
    r'\bцезарь\b',
    r'\bмимоза\b',
    r'\bселедка под шубой\b',
    r'\bхолодец\b',
    r'\bзаливное\b',
    r'\bпаштет\b',
    r'\bрулет\b', # Meat loaf etc
    r'\bкотлеты\b',
    r'\bтефтели\b',
    r'\bфрикадельки\b',
    r'\bголубцы\b',
    r'\bдолма\b',
    r'\bфаршированн[а-я]+\b', # Stuffed...
    r'\bпельмени\b',
    r'\bвареники\b',
    r'\bманты\b',
    r'\bхинкали\b',
    r'\bблины\b',
    r'\bоладьи\b',
    r'\bсырники\b',
    r'\bвафли\b', # Waffles (usually prepared)
    r'\bпанкейки\b',
    r'\bпирог\b',
    r'\bторт\b',
    r'\bпирожное\b',
    r'\bкекс\b',
    r'\bмаффин\b',
    r'\bпончик\b',
    r'\bпеченье\b', # Cookies
    r'\bкрекер\b',
    r'\bчипсы\b',
    r'\bпопкорн\b',
    r'\bбатончик\b',
    r'\bмюсли\b',
    r'\bгранола\b',
    r'\bхлопья\b', # Cereal flakes (often composite)
    r'\bготовый завтрак\b',
    r'\bдетское питание\b', # Baby food (often composite)
    r'\bсмесь для\b', # Mix for...
    r'\bобед\b', # Dinner/Lunch
    r'\bужин\b',
    r'\bзавтрак\b',
    r'\bфаст-фуд\b',
    r'\bресторан\b',
    r'\bшкольн[а-я]+\b', # School lunch
]

# Regex patterns to remove (case insensitive)
PATTERNS_TO_REMOVE = [
    r'\s*\(.*?\)',  # Parentheses content
    r'\bпромышленн[а-я]+\b', # industrial
    r'\bпромышленного приготовления\b',
    r'\bкоммерческ[а-я]+\b', # commercial
    r'\bресторан[а-я]*\b', # restaurant
    r'\bфаст-?фуд[а-я]*\b', # fast food
    r'\bдомашн[а-я]+ рецепт[а-я]*\b', # home recipe
    r'\bnfs\b', # NFS
    r'\bns\b', # NS
    r'\bторговая марка магазина\b', # store brand
    r'\bобычная упаковка\b', # regular packaging
    r'\bимпортн[а-я]+\b', # imported
    r'\bс добавлением витамин[а-я]*\b', # with added vitamins
    r'\bобогащенн[а-я]+\b', # enriched
    r'\bнеобогащенн[а-я]+\b', # unenriched
    r'\bотборн[а-я]+\b', # select/choice
    r'\bсорт [а-яa-z]\b', # grade A
    r'\busda\b', # USDA
    r'\bдлительного хранения\b', # shelf stable
    r'\bготов[а-я]+ к употреблению\b', # ready to eat
    r'\bсалатное или кулинарное\b', # salad or culinary
    r'\bобычн[а-я]+\b', # regular
    r'\bоригинальн[а-я]+\b', # original
    r'\bна (водопроводной|бутилированной|детской) воде\b', # on ... water
    r'\bс добавлением кальция\b', # with calcium
    r'\bкошерн[а-я]+\b', # kosher
    r'\bбез сухих веществ\b', # without solids
    r'\bобрезанн[а-я]+ до \d+.*?\b', # trimmed to ...
    r'\bтолько отделяемое.*?\b', # separable ... only
    r'\bбез костей\b', # boneless
    r'\bс костями\b', # bone-in
    r'\bбез косточек\b', # seedless/boneless
    r'\bс косточками\b', # with seeds
    r'\bнеподготовленн[а-я]+\b', # unprepared
    r'\bподготовленн[а-я]+\b', # prepared
    r'\bраскрошенный\b', # crumbled
    r'\bнарезанн[а-я]+\b', # sliced/chopped
    r'\bкубиками\b', # diced
    r'\bтертый\b', # grated
    r'\bжидкий\b', # liquid
    r'\bгранулированный\b', # granulated
    r'\bпалочка\b', # stick (butter)
    r'\bбрусок\b', # block
    r'\bломтик[а-я]*\b', # slice
    r'\bзерно\b',
    r'\bядро\b',
    r'\bсемя\b', # keep?
    r'\bновозеландск[а-я]+\b', # New Zealand
    r'\bавстралийск[а-я]+\b', # Australian
    r'\bамериканск[а-я]+\b', # American
    r'\bотделяемое\b', # separable
    r'\bпостное\b', # lean
    r'\bжирное\b', # fat
    r'\bмясо\b', # meat (generic "meat" word in description often redundant)
    r'\bсмесь\b', # mixture
    r'\bсорта\b', # grades
    r'\bсубпродукты\b', # variety meats (often redundant if specific organ named)
    r'\bбыстрого обжаривания\b', # fast frying
    r'\bмедленного приготовления\b', # slow cooking
    r'\bна пару\b', # steamed
    r'\bотварн[а-я]+\b', # boiled
    r'\bтушен[а-я]+\b', # braised
    r'\bжарен[а-я]+\b', # fried
    r'\bпечен[а-я]+\b', # baked
    r'\bзапеченн[а-я]+\b', # roasted
    r'\bподжаренн[а-я]+\b', # toasted
    r'\bгриль\b', # grilled
    r'\bбарбекю\b', # bbq
    r'\bкопчен[а-я]+\b',
    r'\bвялен[а-я]+\b',
    r'\bсолен[а-я]+\b',
    r'\bмаринованн[а-я]+\b',
    r'\bпо рецепту\b',
    r'\bприготовления\b',
    r'\bприготовленн[а-я]+\b',
    r'\bспециальная формула\b',
    r'\bс низким содержанием.*?\b',
    r'\bбез соли\b',
    r'\bс солью\b',
    r'\bс добавлением.*?\b',
    r'\bобогащенн[а-я]+\b',
    r'\bнеобогащенн[а-я]+\b',
    r'\bиз цельнозерновой муки\b',
    r'\bиз белой муки\b',
    r'\bв собственном соку\b',
    r'\bв сиропе\b',
    r'\bв масле\b',
    r'\bв воде\b',
    r'\bв рассоле\b',
    r'\bв соусе\b',
    r'\bзамороженн[а-я]+\b',
    r'\bконсервированн[а-я]+\b',
    r'\bсушен[а-я]+\b',
    r'\bсвеж[а-я]+\b',
    r'\bсыр(ая|ые|ой|ом|ого)\b',
    r'\bобработанн[а-я]+\b',
    r'\bнеобработанн[а-я]+\b',
    r'\bочищенн[а-я]+\b',
    r'\bнеочищенн[а-я]+\b',
    r'\bс кожицей\b',
    r'\bбез кожицы\b',
    r'\bс косточкой\b',
    r'\bбез косточки\b',
    r'\bс семенами\b',
    r'\bбез семян\b',
    r'\bцел(ая|ое|ый|ые)\b',
    r'\bнарезанн[а-я]+\b',
    r'\bломтиками\b',
    r'\bкусочками\b',
    r'\bизмельченн[а-я]+\b',
    r'\bтертый\b',
    r'\bмолотый\b',
    r'\bжидкий\b',
    r'\bрастворимый\b',
    r'\bгранулированный\b',
    r'\bпорошкообразный\b',
    r'\bквашен[а-я]+\b',
    r'\bмочен[а-я]+\b',
    r'\bсвеж[а-я]+\b', # fresh
    r'\bнатуральн[а-я]+\b',
    r'\bорганическ[а-я]+\b',
    r'\bдиетическ[а-я]+\b',
    r'\bдетск[а-я]+\b',
    r'\bспортивн[а-я]+\b',
    r'\bфункциональн[а-я]+\b',
    r'\bлечебн[а-я]+\b',
    r'\bпрофилактическ[а-я]+\b',
    r'\bспециализированн[а-я]+\b',
    r'\bтрадиционн[а-я]+\b',
    r'\bклассическ[а-я]+\b',
    r'\bдомашн[а-я]+\b',
    r'\bдеревенск[а-я]+\b',
    r'\bфермерск[а-я]+\b',
    r'\bэлитн[а-я]+\b',
    r'\bпремиум\b',
    r'\bэкстра\b',
    r'\bвысший сорт\b',
    r'\bпервый сорт\b',
    r'\bвторой сорт\b',
    r'\bтретий сорт\b',
    r'\bгост\b',
    r'\bту\b',
    r'\bсто\b',
    r'\bдюйм[а-я]*\b', # inch
    r'\bжир\b', # fat (noun)
    r'\bобрез[а-я]*\b', # trimmings/trimmed
    r'\bтолщин[а-я]*\b', # thickness
    r'\bмрамор[а-я]*\b', # marble
    r'\bоценка\b', # score
    r'\bссылка\b', # link
    r'\bнаружный\b', # external
    r'\bвнутренний\b', # internal
    r'\bшовный\b', # seam
    r'\bпо выбору\b', # choice
    r'\bвсе\b', # all
    r'\bтолько\b', # only
    r'\b\d+/\d+\b', # fractions
    r'\bи\b', # and
    r'\bили\b', # or
    r'\bдля\b', # for
    r'\bна\b', # on
    r'\bс\b', # with
    r'\bбез\b', # without
    r'\bв\b', # in
    r'\bиз\b', # from
    r'\bпо\b', # by
    r'\bк\b', # to
    r'\bдо\b', # up to
    r'\bпри\b', # at
    r'\bпод\b', # under
    r'\bнад\b', # over
    r'\bот\b', # from
    r'\bу\b', # at
    r'\bо\b', # about
    r'\bоб\b', # about
    r'\bза\b', # for
    r'\bчерез\b', # through
    r'\bмежду\b', # between
    r'\bперед\b', # before
    r'\bпосле\b', # after
    r'\bвокруг\b', # around
    r'\bвдоль\b', # along
    r'\bпротив\b', # against
    r'\bсреди\b', # among
    r'\bкроме\b', # except
    r'\bвместо\b', # instead of
    r'\bвне\b', # outside
    r'\bвнутри\b', # inside
    r'\bсквозь\b', # through
    r'\bмимо\b', # past
    r'\bоколо\b', # near
    r'\bвозле\b', # near
    r'\bрядом\b', # near
    r'\bблиз\b', # near
    r'\bвблизи\b', # near
    r'\bвдали\b', # far
    r'\bнапротив\b', # opposite
    r'\bпосреди\b', # in the middle
    r'\bпосередине\b', # in the middle
    r'\bсзади\b', # behind
    r'\bспереди\b', # in front
    r'\bсверху\b', # above
    r'\bснизу\b', # below
    r'\bслева\b', # left
    r'\bсправа\b', # right
    r'\bво\b', # in
    r'\bсо\b', # with
    r'\bко\b', # to
    r'\bоб\b', # about
    r'\bобо\b', # about
    r'\bбезо\b', # without
    r'\bизо\b', # from
    r'\bподо\b', # under
    r'\bнадо\b', # over
    r'\bото\b', # from
    r'\bпередо\b', # before
    r'\bмною\b', # me
    r'\bтобой\b', # you
    r'\bсобой\b', # self
    r'\bнами\b', # us
    r'\bвами\b', # you
    r'\bими\b', # them
    r'\bкем\b', # whom
    r'\bчем\b', # what
    r'\bтем\b', # that
    r'\bвсем\b', # all
    r'\bникем\b', # no one
    r'\bничем\b', # nothing
    r'\bэтим\b', # this
    r'\bтем\b', # that
    r'\bсамим\b', # self
    r'\bсамими\b', # selves
    r'\bмоим\b', # mine
    r'\bтвоим\b', # yours
    r'\bсвоим\b', # own
    r'\bнашим\b', # ours
    r'\bвашим\b', # yours
    r'\bих\b', # theirs
    r'\bего\b', # his
    r'\bее\b', # her
    r'\bих\b', # their
    r'\bмой\b', # my
    r'\bтвой\b', # your
    r'\bсвой\b', # own
    r'\bнаш\b', # our
    r'\bваш\b', # your
    r'\bих\b', # their
    r'\bэтот\b', # this
    r'\bтот\b', # that
    r'\bтакой\b', # such
    r'\bкакой\b', # what
    r'\bчей\b', # whose
    r'\bкоторый\b', # which
    r'\bкто\b', # who
    r'\bчто\b', # what
    r'\bгде\b', # where
    r'\bкогда\b', # when
    r'\bкуда\b', # where
    r'\bоткуда\b', # from where
    r'\bпочему\b', # why
    r'\bзачем\b', # what for
    r'\bкак\b', # how
    r'\bсколько\b', # how much
]

def clean_name(name):
    if not isinstance(name, str):
        return ""
    
    # Lowercase
    name = name.lower()
    
    # Remove patterns
    for pattern in PATTERNS_TO_REMOVE:
        name = re.sub(pattern, '', name)
    
    # Replace punctuation with space
    name = re.sub(r'[,;]', ' ', name)
    
    # Remove extra spaces
    name = re.sub(r'\s+', ' ', name).strip()
    
    return name

def calculate_score(row):
    score = 0
    # Check for non-zero/non-empty values
    # Values are strings with commas, need to parse
    for col in ['protein', 'phe', 'fat', 'carbs', 'energy']:
        val = row.get(col, 0)
        if isinstance(val, str):
            val = val.replace(',', '.').strip()
            try:
                fval = float(val)
                if fval > 0:
                    score += 1
            except:
                pass
        elif isinstance(val, (int, float)):
            if val > 0:
                score += 1
    return score

def semantic_deduplication(df):
    print("Performing semantic deduplication (AI)...")
    try:
        from sklearn.feature_extraction.text import TfidfVectorizer
        from sklearn.metrics.pairwise import cosine_similarity
        import numpy as np
    except ImportError:
        print("scikit-learn not found. Skipping semantic deduplication.")
        return df

    # Vectorize names
    names = df['clean_name'].tolist()
    vectorizer = TfidfVectorizer(analyzer='char_wb', ngram_range=(3, 5)) # Character n-grams for fuzzy matching
    tfidf_matrix = vectorizer.fit_transform(names)
    
    # Calculate similarity
    # This can be memory intensive for large datasets. 
    # For 12k rows, 12k*12k matrix is ~144M floats, ~500MB. Should be fine.
    cosine_sim = cosine_similarity(tfidf_matrix, tfidf_matrix)
    
    # Group similar items
    # We will iterate and mark items to drop
    to_drop = set()
    
    # Threshold for similarity
    threshold = 0.85 
    
    # We want to keep the "best" one in each group.
    # The dataframe is already sorted by Score (desc) and Length (asc).
    # So the first one we encounter is the "best".
    
    indices = df.index.tolist()
    
    for i in range(len(names)):
        if indices[i] in to_drop:
            continue
            
        # Find all similar items
        # We only look forward to avoid double counting and because we want to keep the first one (best score)
        similar_indices = np.where(cosine_sim[i] > threshold)[0]
        
        for j in similar_indices:
            if i == j:
                continue
            if indices[j] in to_drop:
                continue
            
            # Mark for deletion
            to_drop.add(indices[j])
            
    print(f"Identified {len(to_drop)} semantic duplicates.")
    
    return df.drop(to_drop)

def main():
    print("Reading CSV...")
    try:
        df = pd.read_csv(INPUT_FILE, sep=';', decimal=',')
    except Exception as e:
        print(f"Error: {e}")
        return

    print(f"Original rows: {len(df)}")
    
    print("Cleaning names and filtering rows...")
    
    # Function to check if row should be dropped
    def should_drop(name):
        if not isinstance(name, str):
            return False
        name_lower = name.lower()
        for pattern in PATTERNS_TO_DROP_ROW:
            if re.search(pattern, name_lower):
                return True
        return False

    # Filter rows first
    initial_count = len(df)
    df = df[~df['name'].apply(should_drop)]
    print(f"Dropped {initial_count - len(df)} rows (Recipes/Composite dishes).")

    df['clean_name'] = df['name'].apply(clean_name)
    
    # Remove empty names
    df = df[df['clean_name'] != '']
    
    # Calculate score
    print("Calculating scores...")
    df['data_score'] = df.apply(calculate_score, axis=1)
    
    # Sort: 
    # 1. Clean Name (to group)
    # 2. Data Score (descending) - prioritize data
    # 3. Original Name Length (ascending) - prefer shorter names if scores equal? 
    #    Actually, maybe prefer longer names if they have more info? 
    #    User said "remove extra words", so maybe shorter is better.
    #    Let's go with shorter original name.
    df['name_len'] = df['name'].str.len()
    df = df.sort_values(by=['clean_name', 'data_score', 'name_len'], ascending=[True, False, True])
    
    # Drop duplicates
    print("Dropping duplicates...")
    df_dedup = df.drop_duplicates(subset=['clean_name'], keep='first')
    
    print(f"Cleaned rows: {len(df_dedup)}")
    print(f"Removed {len(df) - len(df_dedup)} duplicates.")
    
    # Semantic Deduplication
    df_dedup = semantic_deduplication(df_dedup)
    
    # Save
    # Use cleaned name as the final name
    df_dedup['name'] = df_dedup['clean_name'].str.capitalize()
    
    # Drop helper columns
    df_final = df_dedup.drop(columns=['clean_name', 'data_score', 'name_len'])
    
    # Write to CSV
    df_final.to_csv(OUTPUT_FILE, sep=';', decimal=',', index=False, encoding='utf-8-sig')
    print(f"Saved to {OUTPUT_FILE}")
    
    # Show examples
    print("\nExamples of cleaning (Original -> Cleaned):")
    sample = df.sample(10)
    for _, row in sample.iterrows():
        print(f"{row['name']} -> {clean_name(row['name'])}")

if __name__ == '__main__':
    main()
