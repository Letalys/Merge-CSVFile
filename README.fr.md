# Merge-CSVFile

[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue)](https://github.com/Letalys/RomStationRebase/releases/latest)

**[English](README.md) · [Français](README.fr.md)**

Script PowerShell de fusion de deux fichiers CSV, offrant deux modes de fusion
(empilement ou jointure sur clé), une déduplication paramétrable, l'export des
enregistrements sans correspondance et une journalisation optionnelle.

## Sommaire

- [Présentation](#présentation)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Concepts](#concepts)
- [Syntaxe](#syntaxe)
- [Paramètres](#paramètres)
- [Exemples détaillés](#exemples-détaillés)
- [Fichiers produits](#fichiers-produits)
- [Codes de sortie](#codes-de-sortie)
- [Journalisation](#journalisation)
- [Limites connues](#limites-connues)

## Présentation

`Merge-CSVFile.ps1` fusionne deux fichiers CSV selon l'un des deux modes suivants :

- **Union** : empile les lignes des deux fichiers, en unifiant leurs colonnes.
- **Join** : combine sur une même ligne les colonnes des enregistrements partageant
  une clé commune.

Le script gère par ailleurs la déduplication des résultats, la traçabilité de l'origine
des lignes, des séparateurs de colonnes distincts par fichier, ainsi qu'une comparaison
de clés insensible à la casse par défaut. Il ne dépend d'aucun module externe.

## Prérequis

- Windows PowerShell 5.1 ou PowerShell 7 et versions ultérieures.
- Aucun module complémentaire n'est requis.
- Les fichiers d'entrée doivent comporter une ligne d'en-tête (noms de colonnes).

## Installation

Le script est autonome. Il suffit de récupérer `Merge-CSVFile.ps1` et de l'exécuter
depuis une console PowerShell.

Selon la politique d'exécution en vigueur sur le poste, il peut être nécessaire
d'autoriser l'exécution du script pour la session courante :

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## Concepts

### Modes de fusion

| Mode | Opération | Effet |
|------|-----------|-------|
| `Union` | Empilement | Ajoute les lignes des deux fichiers les unes à la suite des autres. L'ensemble des colonnes est unifié ; une ligne reçoit une valeur vide pour les colonnes qu'elle ne possède pas. |
| `Join` | Jointure | Rapproche les enregistrements partageant une valeur de clé commune et combine leurs colonnes sur une seule ligne. |

L'empilement agit sur les **lignes**, la jointure combine les **colonnes**. Le choix du
mode dépend du résultat recherché, indépendamment de la structure des fichiers source.

### Comportement de la jointure

En mode `Join`, le paramètre `-JoinType` détermine le traitement des enregistrements du
fichier 1 dépourvus de correspondance dans le fichier 2 :

| Valeur | Comportement |
|--------|--------------|
| `KeepUnmatched` (défaut) | Conserve toutes les lignes du fichier 1. Les colonnes du fichier 2 restent vides en l'absence de correspondance. |
| `MatchedOnly` | Ne conserve que les lignes disposant d'une correspondance dans les deux fichiers. |

Lorsqu'une même colonne (hors clé) existe dans les deux fichiers, son traitement dépend du
paramètre `-ColumnConflict` :

| Valeur | Comportement |
|--------|--------------|
| `Suffix` (défaut) | Les deux versions sont conservées, suffixées `_F1` et `_F2`. |
| `PreferF1` | Une seule colonne est conservée, la valeur du fichier 1 étant privilégiée. |
| `PreferF2` | Une seule colonne est conservée, la valeur du fichier 2 étant privilégiée. |

Avec `PreferF1` ou `PreferF2`, le paramètre `-ConflictEmptyValue` détermine le comportement
lorsque la valeur privilégiée est vide (chaîne nulle ou composée uniquement d'espaces) :

| Valeur | Comportement |
|--------|--------------|
| `Strict` (défaut) | La valeur privilégiée est conservée, même vide. |
| `Fallback` | La valeur de l'autre fichier est utilisée lorsque la valeur privilégiée est vide. |

La comparaison des clés est **insensible à la casse par défaut** (`PC-01` équivaut à
`pc-01`), conformément au comportement d'Active Directory pour les noms de machines. Le
commutateur `-CaseSensitiveKey` impose une comparaison sensible à la casse.

### Déduplication

La déduplication conserve une seule occurrence par clé, selon la stratégie retenue :

| Stratégie | Comportement |
|-----------|--------------|
| `None` (défaut) | Aucune déduplication. |
| `KeepFirst` | Conserve la première occurrence rencontrée. |
| `KeepLast` | Conserve la dernière occurrence rencontrée. |

La clé de déduplication est déterminée comme suit :

1. Si `-DeduplicateColumn` est fourni, la colonne désignée sert de clé.
2. Sinon, en mode `Join`, la clé du fichier 1 est utilisée.
3. Sinon, en mode `Union`, la déduplication porte sur la ligne entière (concaténation de
   toutes les colonnes).

L'ordre de référence (KeepFirst/KeepLast) correspond à l'ordre d'apparition des lignes dans les
fichiers source.

## Syntaxe

Mode Union :

```powershell
Merge-CSVFile.ps1 -Union -InputCSV1 <chemin> -InputCSV2 <chemin> -OutputPath <dossier>
                  [-StrictSchema]
                  [-Deduplicate <None|KeepFirst|KeepLast>] [-DeduplicateColumn <nom>]
                  [-AddSourceFileInfo]
                  [-InputDelimiter1 <car>] [-InputDelimiter2 <car>] [-OutputDelimiter <car>]
                  [-OutputLog <dossier>]
```

Mode Join :

```powershell
Merge-CSVFile.ps1 -Join -InputCSV1 <chemin> -InputCSV2 <chemin> -OutputPath <dossier>
                  -KeyFile1 <nom> -KeyFile2 <nom>
                  [-JoinType <KeepUnmatched|MatchedOnly>] [-CaseSensitiveKey]
                  [-ColumnConflict <Suffix|PreferF1|PreferF2>]
                  [-ConflictEmptyValue <Strict|Fallback>]
                  [-NoMatchOutputPath <dossier>]
                  [-Deduplicate <None|KeepFirst|KeepLast>] [-DeduplicateColumn <nom>]
                  [-AddSourceFileInfo]
                  [-InputDelimiter1 <car>] [-InputDelimiter2 <car>] [-OutputDelimiter <car>]
                  [-OutputLog <dossier>]
```

Le mode est sélectionné par le commutateur `-Union` ou `-Join`, mutuellement exclusifs.
Les paramètres propres au mode Join (`-KeyFile1`, `-KeyFile2`, `-JoinType`,
`-CaseSensitiveKey`, `-ColumnConflict`, `-ConflictEmptyValue`, `-NoMatchOutputPath`) ne sont
acceptés qu'avec `-Join`. De même, `-StrictSchema` n'est accepté qu'avec `-Union`. Cette
restriction est assurée par les jeux de paramètres (parameter sets) et signalée par
PowerShell en cas d'usage incorrect.

## Paramètres

| Paramètre | Mode | Obligatoire | Défaut | Description |
|-----------|------|:-----------:|--------|-------------|
| `-Union` | — | Oui (ou `-Join`) | — | Sélectionne le mode empilement. |
| `-Join` | — | Oui (ou `-Union`) | — | Sélectionne le mode jointure. |
| `-InputCSV1` | Union / Join | Oui | — | Chemin du premier fichier CSV. |
| `-InputCSV2` | Union / Join | Oui | — | Chemin du second fichier CSV. |
| `-OutputPath` | Union / Join | Oui | — | Dossier de destination du fichier fusionné. Créé s'il n'existe pas. |
| `-KeyFile1` | Join | Oui | — | Nom de la colonne clé dans le fichier 1. |
| `-KeyFile2` | Join | Oui | — | Nom de la colonne clé dans le fichier 2. |
| `-JoinType` | Join | Non | `KeepUnmatched` | Traitement des enregistrements non appariés du fichier 1. |
| `-ColumnConflict` | Join | Non | `Suffix` | Traitement des colonnes en collision : `Suffix`, `PreferF1`, `PreferF2`. |
| `-ConflictEmptyValue` | Join | Non | `Strict` | Avec `PreferF1`/`PreferF2`, gestion de la valeur privilégiée vide : `Strict` ou `Fallback`. |
| `-CaseSensitiveKey` | Join | Non | (insensible) | Rend la comparaison des clés sensible à la casse. |
| `-NoMatchOutputPath` | Join | Non | — | Dossier d'export des enregistrements sans correspondance. |
| `-StrictSchema` | Union | Non | (désactivé) | Exige des colonnes strictement identiques entre les deux fichiers. |
| `-Deduplicate` | Union / Join | Non | `None` | Stratégie de déduplication : `None`, `KeepFirst`, `KeepLast`. |
| `-DeduplicateColumn` | Union / Join | Non | — | Colonne servant de clé de déduplication. |
| `-AddSourceFileInfo` | Union / Join | Non | (désactivé) | Ajoute les colonnes de traçabilité `SourceFileF1` et `SourceFileF2`. |
| `-InputDelimiter1` | Union / Join | Non | `;` | Séparateur de colonnes du fichier 1. |
| `-InputDelimiter2` | Union / Join | Non | `;` | Séparateur de colonnes du fichier 2. |
| `-OutputDelimiter` | Union / Join | Non | `;` | Séparateur de colonnes des fichiers produits. |
| `-OutputLog` | Union / Join | Non | — | Dossier de destination du journal d'exécution. |

## Exemples détaillés

Les exemples ci-dessous utilisent le séparateur `;` (valeur par défaut). Le résultat de
chaque commande est présenté à la suite.

### Exemple 1 — Empilement simple

Concaténer deux collectes d'inventaire issues de deux sites, en conservant tous les
enregistrements.

`inventaire-site-a.csv` :

```
ComputerName;OS;EvaluationDate
PC-01;Windows 11;2026/05/20 10:00:00
PC-02;Windows 10;2026/05/20 10:05:00
```

`inventaire-site-b.csv` :

```
ComputerName;OS;EvaluationDate
PC-03;Windows 11;2026/05/21 09:00:00
PC-01;Windows 11;2026/05/21 09:02:00
```

```powershell
.\Merge-CSVFile.ps1 -Union `
    -InputCSV1 "C:\Data\inventaire-site-a.csv" `
    -InputCSV2 "C:\Data\inventaire-site-b.csv" `
    -OutputPath "C:\Reports"
```

Résultat :

```
ComputerName;OS;EvaluationDate
PC-01;Windows 11;2026/05/20 10:00:00
PC-02;Windows 10;2026/05/20 10:05:00
PC-03;Windows 11;2026/05/21 09:00:00
PC-01;Windows 11;2026/05/21 09:02:00
```

### Exemple 2 — Empilement avec déduplication par machine

Conserver une seule ligne par valeur de `ComputerName`. Les deux occurrences de PC-01,
bien que distinctes par leur date, sont rapprochées sur la seule colonne `ComputerName`.

```powershell
.\Merge-CSVFile.ps1 -Union `
    -InputCSV1 "C:\Data\inventaire-site-a.csv" `
    -InputCSV2 "C:\Data\inventaire-site-b.csv" `
    -Deduplicate KeepFirst -DeduplicateColumn "ComputerName" `
    -OutputPath "C:\Reports"
```

Résultat (la stratégie `KeepFirst` conserve la première occurrence de PC-01) :

```
ComputerName;OS;EvaluationDate
PC-01;Windows 11;2026/05/20 10:00:00
PC-02;Windows 10;2026/05/20 10:05:00
PC-03;Windows 11;2026/05/21 09:00:00
```

En l'absence de `-DeduplicateColumn`, la déduplication porterait sur la ligne entière ;
les deux lignes PC-01 étant différentes, elles seraient toutes deux conservées.

### Exemple 3 — Empilement strict

Empiler deux fichiers censés être homogènes, en interrompant le traitement si leurs
colonnes diffèrent.

```powershell
.\Merge-CSVFile.ps1 -Union -StrictSchema `
    -InputCSV1 "C:\Data\inventaire-site-a.csv" `
    -InputCSV2 "C:\Data\inventaire-site-b.csv" `
    -OutputPath "C:\Reports"
```

Avec les fichiers de l'exemple 1 (colonnes identiques), le résultat est celui de l'exemple
1. Si une colonne diffère entre les deux fichiers, le script s'arrête avec le code de sortie
`2` et consigne dans le journal les colonnes présentes dans un seul des deux fichiers.

### Exemple 4 — Jointure sur des clés de noms différents

Croiser un inventaire technique avec un export d'annuaire afin de produire une vue
consolidée par machine. La clé se nomme `ComputerName` dans le premier fichier et `Name`
dans le second.

`inventaire.csv` :

```
ComputerName;OS;SecureBoot
PC-01;Windows 11;True
PC-02;Windows 10;False
```

`ad.csv` :

```
Name;OU;LastLogon
PC-01;OU=Paris;2026/05/20
PC-03;OU=Lyon;2026/05/19
```

```powershell
.\Merge-CSVFile.ps1 -Join `
    -InputCSV1 "C:\Data\inventaire.csv" `
    -InputCSV2 "C:\Data\ad.csv" `
    -KeyFile1 "ComputerName" -KeyFile2 "Name" `
    -JoinType KeepUnmatched `
    -OutputPath "C:\Reports"
```

Résultat :

```
ComputerName;OS;SecureBoot;OU;LastLogon
PC-01;Windows 11;True;OU=Paris;2026/05/20
PC-02;Windows 10;False;;
```

- PC-01, présent dans les deux fichiers, voit ses colonnes combinées.
- PC-02, propre au fichier 1, est conservé (`KeepUnmatched`) avec des colonnes F2 vides.
- PC-03, propre au fichier 2, n'apparaît pas dans le résultat principal. Il peut être
  récupéré via `-NoMatchOutputPath` (voir exemple 5).

La clé du fichier 2 (`Name`) n'est pas reportée : la colonne `ComputerName` fait office
de référence.

### Exemple 4 bis — Fusion des colonnes en collision avec priorité

Reprenons deux fichiers partageant une colonne `OS` (en plus de la clé), avec des valeurs
divergentes. L'objectif est d'obtenir une seule colonne `OS` plutôt que `OS_F1` et `OS_F2`.

`inventaire.csv` :

```
ComputerName;OS
PC-01;Windows 11
PC-02;
```

`reference.csv` :

```
ComputerName;OS;IP
PC-01;Windows 10;192.168.1.10
PC-02;Windows 10;192.168.1.20
```

Commande avec priorité au fichier 1 et repli sur le fichier 2 si la valeur du fichier 1
est vide :

```powershell
.\Merge-CSVFile.ps1 -Join `
    -InputCSV1 "C:\Data\inventaire.csv" `
    -InputCSV2 "C:\Data\reference.csv" `
    -KeyFile1 "ComputerName" -KeyFile2 "ComputerName" `
    -ColumnConflict PreferF1 -ConflictEmptyValue Fallback `
    -OutputPath "C:\Reports"
```

Résultat :

```
ComputerName;OS;IP
PC-01;Windows 11;192.168.1.10
PC-02;Windows 10;192.168.1.20
```

- PC-01 : la valeur `OS` du fichier 1 (`Windows 11`) est conservée, étant non vide.
- PC-02 : la valeur `OS` du fichier 1 étant vide, le repli fournit celle du fichier 2
  (`Windows 10`).

Avec `-ConflictEmptyValue Strict`, la colonne `OS` de PC-02 serait restée vide.

### Exemple 5 — Jointure restreinte avec export des écarts et traçabilité

Ne conserver que les machines présentes dans les deux fichiers, exporter séparément les
enregistrements sans correspondance et tracer le fichier d'origine de chaque ligne. Cet
exemple réutilise les fichiers `inventaire.csv` et `ad.csv` de l'exemple 4.

```powershell
.\Merge-CSVFile.ps1 -Join `
    -InputCSV1 "C:\Data\inventaire.csv" `
    -InputCSV2 "C:\Data\ad.csv" `
    -KeyFile1 "ComputerName" -KeyFile2 "Name" `
    -JoinType MatchedOnly `
    -NoMatchOutputPath "C:\Reports\Ecarts" `
    -AddSourceFileInfo `
    -OutputPath "C:\Reports"
```

Fichier principal `MergedCSV_<horodatage>.csv` (seul PC-01 est présent dans les deux
fichiers) :

```
ComputerName;OS;SecureBoot;OU;LastLogon;SourceFileF1;SourceFileF2
PC-01;Windows 11;True;OU=Paris;2026/05/20;C:\Data\inventaire.csv;C:\Data\ad.csv
```

Fichier `Ecarts\MergedCSV_<horodatage>_NoMatchF1.csv` (présent dans le fichier 1 seulement) :

```
ComputerName;OS;SecureBoot
PC-02;Windows 10;False
```

Fichier `Ecarts\MergedCSV_<horodatage>_NoMatchF2.csv` (présent dans le fichier 2 seulement) :

```
Name;OU;LastLogon
PC-03;OU=Lyon;2026/05/19
```

Les colonnes `SourceFileF1` et `SourceFileF2` du fichier principal indiquent le chemin
complet des fichiers d'origine.

### Exemple 6 — Fichiers aux séparateurs distincts

Fusionner un fichier au séparateur virgule avec un fichier au séparateur point-virgule, en
produisant une sortie au point-virgule.

`export-tiers.csv` (séparateur virgule, clé `Hostname`) :

```
Hostname,Emplacement
PC-01,Bureau 12
PC-02,Bureau 14
```

`inventaire.csv` (séparateur point-virgule, clé `ComputerName`) :

```
ComputerName;OS;SecureBoot
PC-01;Windows 11;True
PC-02;Windows 10;False
```

```powershell
.\Merge-CSVFile.ps1 -Join `
    -InputCSV1 "C:\Data\export-tiers.csv" -InputDelimiter1 "," `
    -InputCSV2 "C:\Data\inventaire.csv" -InputDelimiter2 ";" `
    -OutputDelimiter ";" `
    -KeyFile1 "Hostname" -KeyFile2 "ComputerName" `
    -OutputPath "C:\Reports"
```

Résultat (sortie au point-virgule, la clé `Hostname` du fichier 1 sert de référence) :

```
Hostname;Emplacement;OS;SecureBoot
PC-01;Bureau 12;Windows 11;True
PC-02;Bureau 14;Windows 10;False
```

## Fichiers produits

| Fichier | Condition | Description |
|---------|-----------|-------------|
| `MergedCSV_<horodatage>.csv` | Toujours | Résultat de la fusion, dans `-OutputPath`. |
| `MergedCSV_<horodatage>_NoMatchF1.csv` | Mode Join avec `-NoMatchOutputPath` | Enregistrements du fichier 1 sans correspondance. |
| `MergedCSV_<horodatage>_NoMatchF2.csv` | Mode Join avec `-NoMatchOutputPath` | Enregistrements du fichier 2 sans correspondance. |
| `Merge-CSVFile_<machine>_<horodatage>.log` | Avec `-OutputLog` | Journal d'exécution. |

L'horodatage suit le format `yyyyMMdd-HHmmss`. Les fichiers d'écarts sont systématiquement
créés lorsque `-NoMatchOutputPath` est fourni, y compris lorsqu'ils sont vides, afin
d'attester que le traitement a bien eu lieu.

## Codes de sortie

| Code | Signification |
|:----:|---------------|
| `0` | Succès. |
| `1` | Dossier de sortie inaccessible. |
| `2` | Fichier d'entrée introuvable, ou schémas incompatibles avec `-StrictSchema`. |
| `3` | Erreur de lecture des fichiers CSV. |
| `4` | Échec de l'écriture du fichier fusionné. |
| `99` | Erreur générale non gérée. |

Ces codes permettent l'intégration du script dans une chaîne d'automatisation (tâche
planifiée, pipeline) avec contrôle du résultat.

## Journalisation

Lorsque `-OutputLog` est fourni, un journal horodaté est produit dans le dossier indiqué.
Chaque entrée suit le format suivant :

```
[yyyy-MM-dd HH:mm:ss] [NIVEAU ] Message
```

Les niveaux disponibles sont `DEBUG`, `INFO`, `WARNING` et `ERROR`. En l'absence de
`-OutputLog`, aucun journal n'est généré et l'exécution reste silencieuse. Une défaillance
de l'écriture du journal n'interrompt pas le traitement.

## Limites connues

- **Détection des colonnes.** Les noms de colonnes sont déterminés à partir de la première
  ligne de chaque fichier. Les fichiers CSV bien formés présentent les mêmes colonnes sur
  toutes leurs lignes ; un fichier irrégulier n'est pas pris en charge.
- **Correspondances multiples en jointure.** Si une valeur de clé du fichier 1 correspond à
  plusieurs lignes du fichier 2, la fusion produit autant de lignes en sortie (comportement
  équivalent à une jointure relationnelle standard).
- **Cohérence du séparateur.** Le séparateur déclaré pour un fichier doit correspondre à son
  contenu réel. Un séparateur erroné conduit à une lecture incorrecte des colonnes.
- **Volumétrie.** En mode Join, le fichier 2 est indexé en mémoire. Le traitement convient à
  des volumes courants ; les très grands fichiers (plusieurs centaines de milliers de lignes)
  appellent une vigilance sur la consommation mémoire.
- **Fusion priorisée et lignes sans correspondance.** Lorsqu'une ligne du fichier 1 n'a pas
  de correspondance dans le fichier 2, la valeur privilégiée par `-ColumnConflict PreferF2`
  n'existe pas. Avec `-ConflictEmptyValue Strict`, la colonne fusionnée reste donc vide. Le
  mode `Fallback` corrige ce comportement en reprenant la valeur du fichier 1.

---

## Licence

Distribué sous licence **MIT**. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

© 2026 [Letalys](https://github.com/Letalys)