import pandas as pd

# Charger le fichier CSV
df = pd.read_csv('gaua.csv', sep='\t')

# Filtrer les lignes où nutriscore_score est inférieur à 3
df_filtered = df[df['nutriscore_score'] < 3]

# Écrire les lignes filtrées dans un nouveau fichier CSV avec séparateur \t
df_filtered.to_csv('filtered_gaua.tsv', sep='\t', index=False)

print("Filtered data has been written to 'filtered_gaua.tsv'")
