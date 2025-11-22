import requests
import csv
import time
from math import ceil
from requests.exceptions import ReadTimeout, ConnectionError, HTTPError

# тот же endpoint, что и в ссылке
API_URL = "https://ru.openfoodfacts.org/cgi/search.pl"

PAGE_SIZE = 100          # размер страницы (как в ссылке)
REQUEST_TIMEOUT = 60
MAX_RETRIES = 5
RETRY_BACKOFF = 5

OUTPUT_CSV = "products_russia_full.csv"


def clean_str(value):
    if value is None:
        return ""
    return str(value).strip()


def clean_number(value):
    """
    10.5 -> '10,5'
    """
    if value is None or value == "":
        return ""
    try:
        num = float(value)
        return str(num).replace(".", ",")
    except Exception:
        return ""


def fetch_page(session: requests.Session, page: int) -> dict:
    """
    Запрос одной страницы с ТОЧНО такими же параметрами,
    как в ссылке, + page и json=1.
    """
    params = {
        "action": "process",
        "json": 1,
        "page_size": PAGE_SIZE,
        "page": page,

        # фильтр страны
        "tagtype_0": "countries",
        "tag_contains_0": "contains",
        "tag_0": "Russia",

        # фильтр нутриентов (как в ссылке)
        "nutriment_0": "proteins",
        "nutriment_compare_0": "gte",
        "nutriment_value_0": "0",

        "nutriment_1": "carbohydrates",
        "nutriment_compare_1": "gte",
        "nutriment_value_1": "0",

        # сортировка по полноте данных
        "sort_by": "completeness",
    }

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = session.get(API_URL, params=params, timeout=REQUEST_TIMEOUT)
            resp.raise_for_status()
            return resp.json()
        except (ReadTimeout, ConnectionError) as e:
            print(f"[WARN] Сетевая ошибка на стр. {page}, попытка {attempt}/{MAX_RETRIES}: {e}")
            if attempt == MAX_RETRIES:
                print(f"[ERROR] Стр. {page}: не удалось после {MAX_RETRIES} попыток, пропускаю.")
                return {"products": [], "count": None}
            time.sleep(RETRY_BACKOFF)
        except HTTPError as e:
            status = e.response.status_code if e.response is not None else None
            print(f"[WARN] HTTP {status} на стр. {page}, попытка {attempt}/{MAX_RETRIES}")
            if status and 500 <= status < 600 and attempt < MAX_RETRIES:
                time.sleep(RETRY_BACKOFF)
                continue
            print(f"[ERROR] Стр. {page}: HTTP {status}, пропускаю.")
            return {"products": [], "count": None}
        except ValueError as e:
            # не смогли распарсить JSON — логируем кусок ответа и пропускаем
            try:
                print(f"[ERROR] JSON на стр. {page} не парсится: {e}")
                print(f"Первые 200 символов ответа:\n{resp.text[:200]}")
            except Exception:
                pass
            return {"products": [], "count": None}
        except Exception as e:
            print(f"[ERROR] Неожиданная ошибка на стр. {page}: {e}")
            return {"products": [], "count": None}


def extract_product_row(product: dict) -> list:
    nutr = product.get("nutriments", {}) or {}

    return [
        clean_str(product.get("code", "")),
        clean_str(product.get("product_name", "")),
        clean_str(product.get("generic_name", "")),
        clean_str(product.get("brands", "")),
        clean_str(product.get("categories", "")),
        clean_str(product.get("countries", "")),

        clean_number(nutr.get("proteins_100g", "")),
        clean_number(nutr.get("fat_100g", "")),
        clean_number(nutr.get("carbohydrates_100g", "")),
        clean_number(nutr.get("sugars_100g", "")),
        clean_number(nutr.get("fiber_100g", "")),
        clean_number(nutr.get("salt_100g", "")),

        clean_number(nutr.get("energy-kcal_100g", "")),
        clean_number(nutr.get("energy_100g", "")),

        clean_str(product.get("url", "")),
        clean_str(product.get("image_url", "")),
    ]


def main():
    headers = [
        "code",
        "product_name",
        "generic_name",
        "brands",
        "categories",
        "countries",
        "proteins_100g",
        "fat_100g",
        "carbohydrates_100g",
        "sugars_100g",
        "fiber_100g",
        "salt_100g",
        "energy_kcal_100g",
        "energy_kj_100g",
        "url",
        "image_url",
    ]

    total_written = 0

    session = requests.Session()
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (phe-tracker; +https://openfoodfacts.org)",
        "Accept": "application/json",
    })

    with open(OUTPUT_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=";")
        writer.writerow(headers)

        page = 1
        total_pages = None

        while True:
            print(f"Загружаю страницу {page} (уже записано: {total_written})...")
            data = fetch_page(session, page)
            products = data.get("products", []) or []

            # после первой страницы узнаём общее количество
            if total_pages is None:
                count = data.get("count")
                if count is not None:
                    total_pages = ceil(count / PAGE_SIZE)
                    print(f"Всего найдено продуктов по заданным фильтрам: {count}, страниц: {total_pages}")
                else:
                    total_pages = 500  # запас, чтобы не крутиться бесконечно

            if not products:
                print(f"Страница {page} пустая или с ошибкой, продолжаю дальше.")
            else:
                page_written = 0
                for p in products:
                    writer.writerow(extract_product_row(p))
                    total_written += 1
                    page_written += 1
                print(f"Страница {page}: записано {page_written} продуктов (итого: {total_written})")

            if page >= total_pages:
                break

            page += 1
            time.sleep(1)

    print(f"Готово! Всего записано {total_written} продуктов в {OUTPUT_CSV}")


if __name__ == "__main__":
    main()
