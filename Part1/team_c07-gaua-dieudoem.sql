-- Compte rendu commande utilisés S2.04
-- 1 - Setup
-- Changement de l’encodage : 

SET client_encoding TO utf8;

-- 2 - Ne conserver que les données qui nous intéressent, ici : ’en:pizza-pies-and-quiches’
DELETE FROM openfoodfacts_clean 
WHERE code NOT IN (SELECT code FROM openfoodfacts_clean WHERE food_groups = 'en:pizza-pies-and-quiches');


DELETE FROM openfoodfacts_clean WHERE countries_tags NOT LIKE '%en:united-states%';

-- 2.1 - Exploration
-- Garder les  champs utiles

CREATE TABLE openfoodfacts_clean AS
SELECT
	code,
	url,
	product_name,
	brands_tags,
	stores,
	owner,
	food_groups,
	labels_tags,
	countries,
	countries_tags,
	quantity,
	fat_100g,
	saturated_fat_100g,
	sugars_100g,
	proteins_100g,
	carbohydrates_100g,
	energy_100g,
	salt_100g,
	sodium_100g,
	nutriscore_score,
	nutriscore_grade
FROM
	openfoodfacts;

-- 2.2 - Extraction et nettoyage
-- Supprimer les champs vides et inutiles 
-- Le nutriscore (A,B,C,D,E)
DELETE FROM openfoodfacts_clean
WHERE nutriscore_grade = 'not-applicable' OR nutriscore_grade = 'unknown';


--Le nutriscore_grade (codebar)
DELETE FROM openfoodfacts_clean
WHERE code IS null;

-- les erreurs relatives à la qualité des données
DELETE FROM openfoodfacts_clean 
WHERE code IN (
    SELECT code
    FROM openfoodfacts
    WHERE data_quality_errors_tags IS NOT NULL
);



-- Code barre norme internationale (13 chiffres)
DELETE FROM openfoodfacts_clean
WHERE LENGTH(code) != 13;



-- Supprimer les valeurs > 100 dans les champs qui se terminent par ‘_100g’



DELETE FROM openfoodfacts_clean
WHERE
	(fat_100g < 0 OR fat_100g > 100)
 OR
	(saturated_fat_100g < 0 OR saturated_fat_100g > 100)
OR
	(sugars_100g < 0 OR sugars_100g > 100)
 OR
	(proteins_100g < 0 OR proteins_100g > 100)
 OR
	(carbohydrates_100g < 0 OR carbohydrates_100g > 100)
OR
	(salt_100g < 0 OR salt_100g > 100)
 OR
	(sodium_100g < 0 OR sodium_100g > 100);

-- Creation de computed_energy_100g
-- Energie = Lipide + Protéine + Lipide
-- 1g de protéine = 17 kJ
-- 1g de lipide = 38 kJ 
-- 1g de Glucides = 17 kJ

-- https://www.nutrisens.com/vitalites/comment-decrypter-les-valeurs-nutritionnelles/#:~:text=La%20valeur%20énergétique%20correspond%20à,lipide%20%3D%2038%20kJ%20%3D%209%20kcal

ALTER TABLE openfoodfacts_clean 
ADD COLUMN computed_energy_100g numeric;


UPDATE openfoodfacts_clean
SET computed_energy_100g = ROUND(fat_100g * 38) + (proteins_100g * 17) + (carbohydrates_100g * 17);

-- Création d’un champ 'organic' basé sur le champ avec traduction anglaise et gestion des valeurs vides
ALTER TABLE openfoodfacts_clean
ADD COLUMN organic boolean;


UPDATE openfoodfacts_clean
SET organic = CASE 
                    WHEN EXISTS (
                        SELECT 1 
                        FROM openfoodfacts o 
                        WHERE o.code = openfoodfacts_clean.code 
                        AND o.categories_tags LIKE '%bio%'
                    ) THEN TRUE
                    ELSE FALSE
               END;

-- Création des champs Vegan, Végétarien et Huile de Palme à partir des balises d'analyse des ingrédients
ALTER TABLE openfoodfacts_clean
ADD COLUMN vegan boolean,
ADD COLUMN vegetarian boolean,
ADD COLUMN palm_oil boolean;


UPDATE openfoodfacts_clean
SET
    vegan = CASE
                WHEN openfoodfacts.ingredients_analysis_tags LIKE '%en:vegan%' THEN TRUE
                WHEN openfoodfacts.ingredients_analysis_tags LIKE '%en:non-vegan%' THEN FALSE
                ELSE NULL
            END,
    vegetarian = CASE
                WHEN openfoodfacts.ingredients_analysis_tags LIKE '%en:vegetarian%' THEN TRUE
                WHEN openfoodfacts.ingredients_analysis_tags LIKE '%en:non-vegetarian%' THEN FALSE
                ELSE NULL
            END,
    palm_oil = CASE
                WHEN openfoodfacts.ingredients_analysis_tags LIKE '%en:palm-oil%' THEN TRUE
                ELSE FALSE
            END
FROM openfoodfacts
WHERE openfoodfacts.code = openfoodfacts_clean.code;

-- Ajout de champs pour indiquer les niveaux de graisse, de graisse saturée, de sucres et de sel dans la table

ALTER TABLE openfoodfacts_clean
ADD COLUMN level_fat character varying,
ADD COLUMN level_saturated_fat character varying,
ADD COLUMN level_sugars character varying,
ADD COLUMN level_salt character varying;

UPDATE openfoodfacts_clean
SET
	level_fat = CASE
                	WHEN openfoodfacts.nutrient_levels_tags LIKE '%en:fat-in-high-quantity%' THEN 'h'
                	WHEN openfoodfacts.nutrient_levels_tags LIKE '%en:fat-in-moderate-quantity%' THEN 'm'
                	WHEN openfoodfacts.nutrient_levels_tags LIKE '%en:fat-in-low-quantity%' THEN 'l'
                	ELSE NULL
            	END,
	level_saturated_fat = CASE
                        	WHEN openfoodfacts.nutrient_levels_tags LIKE '%en:saturated-fat-in-high-quantity%' THEN 'h'
                        	WHEN openfoodfacts.nutrient_levels_tags LIKE '%en:saturated-fat-in-moderate-quantity%' THEN 'm'
                        	WHEN openfoodfacts.nutrient_levels_tags LIKE '%en:saturated-fat-in-low-quantity%' THEN 'l'
                        	ELSE NULL
                    	END,
	level_sugars = CASE
                	WHEN openfoodfacts.nutrient_levels_tags LIKE '%en:sugars-in-high-quantity%' THEN 'h'
                	WHEN openfoodfacts.nutrient_levels_tags LIKE '%en:sugars-in-moderate-quantity%' THEN 'm'
                	WHEN openfoodfacts.nutrient_levels_tags LIKE '%en:sugars-in-low-quantity%' THEN 'l'
                	ELSE NULL
            	END,
	level_salt = CASE
                        	WHEN openfoodfacts.nutrient_levels_tags LIKE '%en:salt-in-high-quantity%' THEN 'h'
                        	WHEN openfoodfacts.nutrient_levels_tags LIKE '%en:salt-in-moderate-quantity%' THEN 'm'
                        	WHEN openfoodfacts.nutrient_levels_tags LIKE '%en:salt-in-low-quantity%' THEN 'l'
                        	ELSE NULL
                    	END
FROM openfoodfacts
WHERE openfoodfacts.code = openfoodfacts_clean.code;


-- 3. Exportation
\COPY (
    SELECT * FROM openfoodfacts_clean
) TO 'team_c07.csv' WITH CSV DELIMITER E'\t' NULL 'NA' HEADER;