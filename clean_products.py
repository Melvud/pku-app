import csv

input_filename = 'cleaned_products.csv'
output_filename = 'cleaned_products.csv'

try:
    with open(input_filename, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter=';')
        rows = list(reader)
        fieldnames = reader.fieldnames
        
    print(f"Original rows: {len(rows)}")
    
    cleaned_rows = []
    removed_count = 0
    
    for row in rows:
        phe_val = row.get('phe', '').strip().replace(',', '.')
        try:
            phe_float = float(phe_val)
            if phe_float > 0:
                cleaned_rows.append(row)
            else:
                removed_count += 1
        except ValueError:
            # If Phe is not a number (e.g. empty string), remove it
            removed_count += 1
            
    print(f"Removed rows: {removed_count}")
    print(f"Remaining rows: {len(cleaned_rows)}")
    
    with open(output_filename, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter=';')
        writer.writeheader()
        writer.writerows(cleaned_rows)
        
    print(f"Successfully saved to {output_filename}")

except Exception as e:
    print(f"Error: {e}")
