<#
.SYNOPSIS
    Fusionne deux fichiers CSV selon un mode Union ou Join.

.DESCRIPTION
	Ce script fusionne deux fichiers CSV selon le mode choisi (determine par le ParameterSet) :

	Mode Union :
		Empile toutes les lignes des deux fichiers dans un CSV unique. Les colonnes des deux
		fichiers sont unifiees : une ligne issue du fichier 1 aura des valeurs vides pour les
		colonnes propres au fichier 2, et inversement.
		Avec -StrictSchema : on verifie d'abord que les deux fichiers ont exactement les memes
		colonnes. Toute difference provoque une erreur (utile pour empiler des fichiers censes
		etre homogenes, ex : plusieurs exports du meme type).

	Mode Join :
		Fusionne les lignes qui correspondent sur une cle. On precise le couple de colonnes
		(KeyFile1, KeyFile2) servant de cle de rapprochement.
		Deux comportements via -JoinType :
			- KeepUnmatched : conserve toutes les lignes du fichier 1, completees par le fichier 2
			                  quand une correspondance existe (colonnes F2 vides sinon).
			- MatchedOnly   : ne conserve que les lignes ayant une correspondance dans les deux fichiers.

	Collision de colonnes (mode Join) :
		Lorsque les deux fichiers possedent une colonne de meme nom (hors cle), le traitement
		depend du parametre -ColumnConflict :
			- Suffix (defaut) : les deux versions sont conservees, suffixees _F1 et _F2.
			- PreferF1        : une seule colonne est conservee, valeur du fichier 1 privilegiee.
			- PreferF2        : une seule colonne est conservee, valeur du fichier 2 privilegiee.
		En PreferF1 / PreferF2, le parametre -ConflictEmptyValue regle le cas ou la valeur
		privilegiee est vide (null ou espaces) :
			- Strict (defaut) : la valeur privilegiee est conservee, meme vide.
			- Fallback        : la valeur de l'autre fichier est utilisee si la privilegiee est vide.

	Sensibilite a la casse de la cle (mode Join) :
		Par defaut, le rapprochement des cles est INSENSIBLE a la casse (PC-01 = pc-01), ce qui
		correspond au comportement d'Active Directory pour les noms de machines. L'option
		-CaseSensitiveKey force une comparaison stricte (sensible a la casse).

	Deduplication (option -Deduplicate) :
		Sur la cle (mode Join) ou sur l'ensemble de la ligne (mode Union), conserve une seule
		occurrence selon l'ordre d'apparition :
			- KeepFirst : conserve la premiere occurrence rencontree.
			- KeepLast  : conserve la derniere occurrence rencontree.

	Export des lignes sans correspondance (option -NoMatchOutputPath, mode Join uniquement) :
		Genere deux fichiers :
			- <nom>_NoMatchF1.csv : lignes du fichier 1 sans correspondance dans le fichier 2.
			- <nom>_NoMatchF2.csv : lignes du fichier 2 jamais appariees avec le fichier 1.
		Les deux fichiers sont toujours generes (meme vides) lorsque l'option est active.

	Tracabilite de la source (option -AddSourceFileInfo) :
		Ajoute deux colonnes SourceFileF1 et SourceFileF2 contenant le chemin complet du fichier
		d'origine de la ligne. En Union, une seule des deux colonnes est renseignee par ligne.
		En Join, les deux sont renseignees pour une ligne appariee (SourceFileF2 vide pour une
		ligne KeepUnmatched sans correspondance).

.PARAMETER InputCSV1
	Chemin du premier fichier CSV.

.PARAMETER InputCSV2
	Chemin du second fichier CSV.

.PARAMETER InputDelimiter1
	[Facultatif] Separateur de colonnes du fichier 1. Defaut : ";".

.PARAMETER InputDelimiter2
	[Facultatif] Separateur de colonnes du fichier 2. Defaut : ";".

.PARAMETER OutputDelimiter
	[Facultatif] Separateur de colonnes des fichiers produits (fusionne et non-matchs). Defaut : ";".

.PARAMETER StrictSchema
	[Mode Union, facultatif] Exige que les deux fichiers aient exactement les memes colonnes.
	Toute difference provoque une erreur (exit 2) au lieu d'unifier les colonnes.

.PARAMETER KeyFile1
	[Mode Join] Nom de la colonne cle dans le fichier 1.

.PARAMETER KeyFile2
	[Mode Join] Nom de la colonne cle dans le fichier 2.

.PARAMETER JoinType
	[Mode Join] KeepUnmatched (toutes les lignes du fichier 1) ou MatchedOnly (uniquement les
	correspondances). Defaut : KeepUnmatched.

.PARAMETER ColumnConflict
	[Mode Join] Traitement des colonnes presentes dans les deux fichiers (hors cle) :
	Suffix (defaut, conserve _F1 et _F2), PreferF1 ou PreferF2 (fusionne en une seule colonne).

.PARAMETER ConflictEmptyValue
	[Mode Join] Avec PreferF1 / PreferF2, regle le cas ou la valeur privilegiee est vide :
	Strict (defaut, garde la valeur privilegiee meme vide) ou Fallback (utilise l'autre fichier).
	Sans effet en mode Suffix.

.PARAMETER CaseSensitiveKey
	[Mode Join, facultatif] Rend la comparaison des cles sensible a la casse. Par defaut, la
	comparaison est insensible a la casse.

.PARAMETER NoMatchOutputPath
	[Mode Join, facultatif] Dossier ou exporter les lignes sans correspondance (deux fichiers
	_NoMatchF1 et _NoMatchF2). Toujours generes meme vides si l'option est active.

.PARAMETER Deduplicate
	[Facultatif] Strategie de deduplication : None, KeepFirst ou KeepLast. Defaut : None.
	En mode Join, la deduplication se fait par defaut sur la cle du fichier 1.
	En mode Union, par defaut sur l'ensemble des colonnes de la ligne.
	Le parametre -DeduplicateColumn permet de cibler une colonne precise.

.PARAMETER DeduplicateColumn
	[Facultatif] Nom de la colonne servant de cle de deduplication. Prioritaire sur le
	comportement par defaut. Utile notamment en mode Union pour ne conserver qu'une ligne
	par valeur d'une colonne donnee (ex : ComputerName). Si la colonne est absente du
	resultat, la deduplication retombe sur la ligne entiere (avertissement dans le journal).

.PARAMETER AddSourceFileInfo
	[Facultatif] Ajoute les colonnes SourceFileF1 / SourceFileF2 (chemin complet du fichier source).

.PARAMETER OutputPath
	Dossier ou le CSV fusionne sera ecrit. Le dossier est cree s'il n'existe pas.

.PARAMETER OutputLog
	[Facultatif] Dossier ou le journal d'execution sera ecrit.
	Si non fourni, aucun log n'est genere.

.EXAMPLE
	# Union permissive de deux fichiers aux colonnes differentes :
	.\Merge-CSVFile.ps1 -Union -InputCSV1 "C:\Data\f1.csv" -InputCSV2 "C:\Data\f2.csv" `
	                  -OutputPath "C:\Reports"

.EXAMPLE
	# Union stricte : empile deux exports homogenes, erreur si les colonnes different :
	.\Merge-CSVFile.ps1 -Union -StrictSchema -InputCSV1 "C:\Data\jour1.csv" -InputCSV2 "C:\Data\jour2.csv" `
	                  -OutputPath "C:\Reports"

.EXAMPLE
	# Union avec deduplication sur la colonne ComputerName (une seule ligne par machine) :
	.\Merge-CSVFile.ps1 -Union -InputCSV1 "C:\Data\jour1.csv" -InputCSV2 "C:\Data\jour2.csv" `
	                  -Deduplicate KeepFirst -DeduplicateColumn "ComputerName" `
	                  -OutputPath "C:\Reports"

.EXAMPLE
	# Jointure sur une cle (Name dans F1 = ComputerName dans F2), conserve les non-apparies F1 :
	.\Merge-CSVFile.ps1 -Join -InputCSV1 "C:\Data\ad.csv" -InputCSV2 "C:\Data\sbcert.csv" `
	                  -KeyFile1 "Name" -KeyFile2 "ComputerName" -JoinType KeepUnmatched `
	                  -OutputPath "C:\Reports" -OutputLog "C:\Reports\Logs"

.EXAMPLE
	# Jointure avec fusion des colonnes en collision, valeur du fichier 1 privilegiee,
	# repli sur le fichier 2 si la valeur du fichier 1 est vide :
	.\Merge-CSVFile.ps1 -Join -InputCSV1 "C:\Data\inventaire.csv" -InputCSV2 "C:\Data\ad.csv" `
	                  -KeyFile1 "ComputerName" -KeyFile2 "Name" `
	                  -ColumnConflict PreferF1 -ConflictEmptyValue Fallback `
	                  -OutputPath "C:\Reports"

.EXAMPLE
	# Jointure MatchedOnly, deduplication KeepFirst, export des non-matchs et tracabilite source :
	.\Merge-CSVFile.ps1 -Join -InputCSV1 "C:\Data\f1.csv" -InputCSV2 "C:\Data\f2.csv" `
	                  -KeyFile1 "Name" -KeyFile2 "Name" -JoinType MatchedOnly `
	                  -Deduplicate KeepFirst -NoMatchOutputPath "C:\Reports\NoMatch" `
	                  -AddSourceFileInfo -OutputPath "C:\Reports"

.OUTPUTS
	Un fichier CSV fusionne a l'emplacement OutputPath.

	Convention de nommage : MergedCSV_<yyyyMMdd-HHmmss>.csv

	[Optionnel] Fichiers _NoMatchF1 / _NoMatchF2 a l'emplacement NoMatchOutputPath.
	[Optionnel] Un fichier log a l'emplacement OutputLog.

	Codes de sortie :
		0   : Succes
		1   : Chemin de sortie inaccessible
		2   : Fichier d'entree introuvable ou schemas incompatibles (StrictSchema)
		3   : Erreur de lecture des CSV
		4   : Echec de l'export CSV fusionne
		99  : Erreur generale / inattendue

.NOTES
	Version       : 2.5
	Auteur        : Christophe GOEMAERE
	Date creation : 2026-05-21
	Modifications :
		v1.0 - 2026-05-21 - Version initiale (modes Union / Join, JoinType Left / Inner).
		v2.0 - 2026-05-21 - Passage en ParameterSets Union / Join.
		                    Renommage JoinType : KeepUnmatched / MatchedOnly.
		                    Ajout -NoMatchOutputPath (export des lignes sans correspondance).
		                    Ajout -AddSourceFileInfo (colonnes SourceFileF1 / SourceFileF2).
		v2.1 - 2026-05-21 - Ajout des separateurs parametrables InputDelimiter1 /
		                    InputDelimiter2 / OutputDelimiter (defaut ; partout).
		v2.2 - 2026-05-21 - Ajout -StrictSchema (Union homogene), -CaseSensitiveKey (Join).
		                    Corrections : effet de bord [array]::Reverse, mise en cache des
		                    noms de colonnes, factorisation de la comparaison de cle.
		v2.3 - 2026-05-21 - Ajout -DeduplicateColumn (deduplication cible sur une colonne,
		                    notamment en mode Union).
		v2.4 - 2026-05-21 - Ajout -ColumnConflict (Suffix / PreferF1 / PreferF2) et
		                    -ConflictEmptyValue (Strict / Fallback) pour fusionner les colonnes
		                    en collision en une seule colonne priorisee.
		v2.5 - 2026-05-21 - Renommage des strategies de deduplication FIFO / FILO en
		                    KeepFirst / KeepLast.
#>

[CmdletBinding(DefaultParameterSetName='Union')]
param
(
    # Le switch de mode est obligatoire et determine le ParameterSet (donc les parametres autorises).
    [Parameter(Mandatory=$true, ParameterSetName='Union')]
    [switch]$Union,

    [Parameter(Mandatory=$true, ParameterSetName='Join')]
    [switch]$Join,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$InputCSV1,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$InputCSV2,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$InputDelimiter1 = ";",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$InputDelimiter2 = ";",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputDelimiter = ";",

    # Specifique au mode Union : empilement strict (memes colonnes exigees).
    [Parameter(Mandatory=$false, ParameterSetName='Union')]
    [switch]$StrictSchema,

    # Specifiques au mode Join : cles de rapprochement et comportement de jointure.
    [Parameter(Mandatory=$true, ParameterSetName='Join')]
    [ValidateNotNullOrEmpty()]
    [string]$KeyFile1,

    [Parameter(Mandatory=$true, ParameterSetName='Join')]
    [ValidateNotNullOrEmpty()]
    [string]$KeyFile2,

    [Parameter(Mandatory=$false, ParameterSetName='Join')]
    [ValidateSet('KeepUnmatched','MatchedOnly')]
    [string]$JoinType = 'KeepUnmatched',

    [Parameter(Mandatory=$false, ParameterSetName='Join')]
    [ValidateSet('Suffix','PreferF1','PreferF2')]
    [string]$ColumnConflict = 'Suffix',

    [Parameter(Mandatory=$false, ParameterSetName='Join')]
    [ValidateSet('Strict','Fallback')]
    [string]$ConflictEmptyValue = 'Strict',

    [Parameter(Mandatory=$false, ParameterSetName='Join')]
    [switch]$CaseSensitiveKey,

    [Parameter(Mandatory=$false, ParameterSetName='Join')]
    [string]$NoMatchOutputPath,

    # Communs aux deux modes.
    [Parameter(Mandatory=$false)]
    [ValidateSet('None','KeepFirst','KeepLast')]
    [string]$Deduplicate = 'None',

    [Parameter(Mandatory=$false)]
    [string]$DeduplicateColumn,

    [Parameter(Mandatory=$false)]
    [switch]$AddSourceFileInfo,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [Parameter(Mandatory=$false)]
    [string]$OutputLog
)

# Verbose silencieux par defaut ; toute erreur devient terminante pour etre capturee par les Try/Catch.
$VerbosePreference     = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

$Script:ScriptVersion = "2.5"
$Script:LogFilePath   = $null

#region Fonctions de journalisation
	Function Initialize-LogFile{
		<#
		.SYNOPSIS
			Initialise le fichier de journalisation si OutputLog est fourni.
		#>
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory=$false)][string]$LogFolder,
			[Parameter(Mandatory=$false)][string]$ScriptFileName
		)

		Begin{}
		Process{
			# Si OutputLog n'a pas ete fourni, on ne fait rien (la journalisation est optionnelle).
			if([string]::IsNullOrWhiteSpace($LogFolder)){
				return
			}

			Try{
				# Creation du dossier de log si besoin.
				if(-not (Test-Path $LogFolder)){
					New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
				}

				if([string]::IsNullOrWhiteSpace($ScriptFileName)){
					$ScriptFileName = "Merge-CSVFile"
				}

				# Nom de fichier : <NomScript>_<ComputerName>_<horodatage>.log
				$Timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"
				$LogFileName = "$($ScriptFileName)_$($env:COMPUTERNAME)_$Timestamp.log"
				$Script:LogFilePath = Join-Path -Path $LogFolder -ChildPath $LogFileName

				$InitMessage = "Initialisation du journal d'execution (script v$($Script:ScriptVersion) sur $($env:COMPUTERNAME))."
				"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO]    $InitMessage" | Out-File -FilePath $Script:LogFilePath -Encoding UTF8 -Append
			}Catch{
				# Si l'initialisation echoue, on repasse le chemin a null : la journalisation sera simplement inactive.
				$Script:LogFilePath = $null
			}
		}
		End{}
	}

	Function Write-LogEntry{
		<#
		.SYNOPSIS
			Ecrit une entree dans le fichier de journalisation, si celui-ci est initialise.
		.DESCRIPTION
			Si $Script:LogFilePath est null (OutputLog non fourni), la fonction ne fait rien.
			Sinon elle ajoute une ligne horodatee au format :
				[yyyy-MM-dd HH:mm:ss] [NIVEAU]  Message

			Les erreurs d'ecriture du log sont gerees silencieusement pour ne pas masquer les erreurs du script principal
		.PARAMETER Level
			Niveau de log : DEBUG, INFO, WARNING ou ERROR.
		.PARAMETER Message
			Texte du message a journaliser.
		#>
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory=$true)][ValidateSet('DEBUG','INFO','WARNING','ERROR')][string]$Level,
			[Parameter(Mandatory=$true)][string]$Message
		)

		Begin{}
		Process{
			# Pas de fichier de log initialise -> on sort sans rien faire.
			if($null -eq $Script:LogFilePath){
				return
			}

			Try{
				# Le niveau est complete a 7 caracteres pour aligner visuellement les colonnes du log.
				$LevelPadded = $Level.PadRight(7)
				$Line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$LevelPadded] $Message"
				$Line | Out-File -FilePath $Script:LogFilePath -Encoding UTF8 -Append
			}Catch{
				# Catch volontairement vide : un echec d'ecriture du log ne doit jamais interrompre le script.
			}
		}
		End{}
	}
#endregion Fonctions de journalisation

#region Fonctions utilitaires
	Function Get-ColumnNames{
		<#
		.SYNOPSIS
			Retourne la liste des noms de colonnes d'un jeu de lignes (base sur la 1ere ligne).
		.DESCRIPTION
			Les CSV bien formes ont les memes colonnes sur toutes les lignes, donc lire la
			premiere ligne suffit. Retourne un tableau vide si le jeu est vide.
			Centralise cette lecture pour eviter de rappeler PSObject.Properties partout.
		#>
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory=$true)][AllowEmptyCollection()][PSCustomObject[]]$Rows
		)

		Begin{}
		Process{
			if($Rows.Count -eq 0){
				return ,@()
			}
			return ,@($Rows[0].PSObject.Properties.Name)
		}
		End{}
	}

	Function Get-KeyComparer{
		<#
		.SYNOPSIS
			Retourne le comparateur de chaines a utiliser pour les structures indexees (HashSet, Dictionary).
		.DESCRIPTION
			On centralise ici le choix du comparateur pour que l'indexation des cles (Dictionary)
			et le suivi des cles utilisees (HashSet) appliquent EXACTEMENT la meme regle de casse
			que la comparaison directe. Evite les incoherences entre indexation et comparaison.
		#>
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory=$true)][bool]$CaseSensitive
		)

		Begin{}
		Process{
			if($CaseSensitive){
				return [System.StringComparer]::Ordinal
			}else{
				return [System.StringComparer]::OrdinalIgnoreCase
			}
		}
		End{}
	}
#endregion Fonctions utilitaires

#region Fonctions de fusion
	Function Import-CSVFile{
		<#
		.SYNOPSIS
			Importe un fichier CSV et retourne ses lignes en collection.
		#>
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory=$true)][string]$Path,
			[Parameter(Mandatory=$true)][string]$Delimiter
		)

		Begin{}
		Process{
			Write-LogEntry -Level 'DEBUG' -Message "Lecture du CSV : '$Path' (separateur '$Delimiter')."
			$Rows = Import-Csv -LiteralPath $Path -Delimiter $Delimiter -Encoding UTF8

			# Import-Csv retourne $null pour un fichier vide : on normalise en tableau vide.
			if($null -eq $Rows){
				Write-LogEntry -Level 'WARNING' -Message "CSV vide ou non parsable : '$Path'."
				return ,@()
			}

			# Import-Csv retourne un objet seul (non-tableau) s'il n'y a qu'une ligne : on force le tableau.
			if($Rows -isnot [System.Array]){
				$Rows = @($Rows)
			}

			Write-LogEntry -Level 'INFO' -Message "CSV '$Path' : $($Rows.Count) ligne(s) lue(s)."
			return ,$Rows
		}
		End{}
	}

	Function Test-SameSchema{
		<#
		.SYNOPSIS
			Verifie que deux jeux de lignes ont exactement les memes colonnes (ordre indifferent).
		.DESCRIPTION
			Utilise par le mode Union -StrictSchema. Retourne un objet { IsSame; OnlyInF1; OnlyInF2 }
			pour permettre un message d'erreur precis listant les colonnes divergentes.
			La comparaison des NOMS de colonnes est insensible a la casse (convention CSV usuelle).
		#>
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory=$true)][AllowEmptyCollection()][string[]]$Cols1,
			[Parameter(Mandatory=$true)][AllowEmptyCollection()][string[]]$Cols2
		)

		Begin{}
		Process{
			# Colonnes presentes d'un cote mais pas de l'autre (comparaison insensible a la casse).
			$OnlyInF1 = $Cols1 | Where-Object { $Cols2 -notcontains $_ }
			$OnlyInF2 = $Cols2 | Where-Object { $Cols1 -notcontains $_ }

			$IsSame = (($OnlyInF1.Count -eq 0) -and ($OnlyInF2.Count -eq 0))

			return [PSCustomObject]@{
				IsSame   = $IsSame
				OnlyInF1 = @($OnlyInF1)
				OnlyInF2 = @($OnlyInF2)
			}
		}
		End{}
	}

	Function Add-SourceColumns{
		<#
		.SYNOPSIS
			Ajoute les colonnes SourceFileF1 / SourceFileF2 a une ligne (dictionnaire ordonne).
		.DESCRIPTION
			Centralise l'ajout des colonnes de tracabilite, appele a la fois par Merge-Union et
			Join-TwoRows. La valeur vide ("") sert quand la ligne ne provient pas du fichier concerne.
		#>
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory=$true)][System.Collections.Specialized.OrderedDictionary]$Row,
			[Parameter(Mandatory=$true)][AllowEmptyString()][string]$ValueF1,
			[Parameter(Mandatory=$true)][AllowEmptyString()][string]$ValueF2
		)

		Begin{}
		Process{
			$Row['SourceFileF1'] = $ValueF1
			$Row['SourceFileF2'] = $ValueF2
			return $Row
		}
		End{}
	}

	Function Resolve-ConflictValue{
		<#
		.SYNOPSIS
			Resout la valeur d'une colonne en collision selon la preference et la gestion du vide.
		.DESCRIPTION
			Appelee uniquement en mode PreferF1 / PreferF2. Determine la valeur a conserver pour
			une colonne presente dans les deux fichiers :
				- Preference PreferF1 : valeur privilegiee = F1, valeur de repli = F2.
				- Preference PreferF2 : valeur privilegiee = F2, valeur de repli = F1.
			Gestion du vide (EmptyHandling) :
				- Strict   : on retourne la valeur privilegiee telle quelle, meme si elle est vide.
				- Fallback : si la valeur privilegiee est vide (null ou espaces uniquement), on
				             retourne la valeur de repli.
			Note : pour une ligne F1 sans correspondance F2 (KeepUnmatched), ValueF2 est vide ; en
			PreferF2 + Fallback, on retombe donc naturellement sur la valeur F1.
		#>
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory=$true)][AllowEmptyString()][AllowNull()][string]$ValueF1,
			[Parameter(Mandatory=$true)][AllowEmptyString()][AllowNull()][string]$ValueF2,
			[Parameter(Mandatory=$true)][ValidateSet('PreferF1','PreferF2')][string]$Preference,
			[Parameter(Mandatory=$true)][ValidateSet('Strict','Fallback')][string]$EmptyHandling
		)

		Begin{}
		Process{
			# On determine quelle valeur est privilegiee et laquelle sert de repli.
			if($Preference -eq 'PreferF1'){
				$Primary   = $ValueF1
				$Secondary = $ValueF2
			}else{
				$Primary   = $ValueF2
				$Secondary = $ValueF1
			}

			# En Fallback, si la valeur privilegiee est vide (null ou espaces), on prend l'autre.
			if($EmptyHandling -eq 'Fallback' -and [string]::IsNullOrWhiteSpace($Primary)){
				return $Secondary
			}

			# En Strict (ou si la valeur privilegiee n'est pas vide), on garde la valeur privilegiee.
			return $Primary
		}
		End{}
	}

	Function Merge-Union{
		<#
		.SYNOPSIS
			Empile toutes les lignes des deux jeux de donnees en unifiant les colonnes.
		.DESCRIPTION
			Le jeu de colonnes final est l'union des colonnes des deux fichiers.
			Chaque ligne recoit une valeur vide pour les colonnes qu'elle ne possede pas.
			Si AddSource, ajoute SourceFileF1 / SourceFileF2 (une seule renseignee par ligne).
		#>
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory=$true)][AllowEmptyCollection()][PSCustomObject[]]$Rows1,
			[Parameter(Mandatory=$true)][AllowEmptyCollection()][PSCustomObject[]]$Rows2,
			[Parameter(Mandatory=$true)][bool]$AddSource,
			[Parameter(Mandatory=$true)][string]$Path1,
			[Parameter(Mandatory=$true)][string]$Path2
		)

		Begin{}
		Process{
			# On lit les colonnes de chaque jeu UNE SEULE FOIS (mise en cache) au lieu de les
			# relire a chaque ligne : gain notable sur gros volumes.
			$Cols1 = Get-ColumnNames -Rows $Rows1
			$Cols2 = Get-ColumnNames -Rows $Rows2

			# Le jeu de colonnes final est l'union ordonnee : d'abord celles de F1, puis celles
			# propres a F2 (dans leur ordre d'apparition).
			$AllColumns = New-Object System.Collections.Generic.List[string]
			foreach($Col in $Cols1){
				if($AllColumns -notcontains $Col){ $AllColumns.Add($Col) }
			}
			foreach($Col in $Cols2){
				if($AllColumns -notcontains $Col){ $AllColumns.Add($Col) }
			}

			Write-LogEntry -Level 'INFO' -Message "Mode Union : $($AllColumns.Count) colonne(s) unifiee(s) [$($AllColumns -join ', ')]."

			$Result = New-Object System.Collections.Generic.List[PSCustomObject]

			# On traite les deux jeux l'un apres l'autre. $SetInfo associe a chaque jeu ses colonnes
			# propres (pour savoir, sans recalcul, quelles colonnes la ligne possede reellement)
			# et le drapeau indiquant si c'est F1 ou F2 (pour la colonne source).
			$SetsInfo = @(
				[PSCustomObject]@{ Rows = $Rows1; OwnCols = $Cols1; IsF1 = $true  },
				[PSCustomObject]@{ Rows = $Rows2; OwnCols = $Cols2; IsF1 = $false }
			)

			foreach($SetInfo in $SetsInfo){
				# HashSet des colonnes du jeu courant : test d'appartenance O(1) au lieu de -contains.
				$OwnColsSet = New-Object System.Collections.Generic.HashSet[string] (,[string[]]$SetInfo.OwnCols)

				foreach($Row in $SetInfo.Rows){
					$NewRow = [ordered]@{}
					foreach($Col in $AllColumns){
						if($OwnColsSet.Contains($Col)){
							$NewRow[$Col] = $Row.$Col
						}else{
							# Colonne appartenant a l'autre fichier : valeur vide pour cette ligne.
							$NewRow[$Col] = ""
						}
					}

					if($AddSource){
						# En Union, seule la colonne du fichier d'origine est renseignee.
						$ValF1 = if($SetInfo.IsF1){ $Path1 } else { "" }
						$ValF2 = if($SetInfo.IsF1){ "" } else { $Path2 }
						$NewRow = Add-SourceColumns -Row $NewRow -ValueF1 $ValF1 -ValueF2 $ValF2
					}

					$Result.Add([PSCustomObject]$NewRow)
				}
			}

			Write-LogEntry -Level 'INFO' -Message "Mode Union : $($Result.Count) ligne(s) au total."
			return ,$Result.ToArray()
		}
		End{}
	}

	Function Join-TwoRows{
		<#
		.SYNOPSIS
			Fusionne deux lignes (F1 et F2) en une seule, selon le mode de resolution de collision.
		.DESCRIPTION
			Row2 peut etre $null (cas KeepUnmatched sans correspondance) : les valeurs F2 sont
			alors considerees comme vides.
			La cle du fichier 2 (KeyFile2) n'est pas reportee car redondante avec la cle F1.
			CollisionSet (HashSet) liste les colonnes presentes dans les deux fichiers (hors cles).

			Traitement des colonnes en collision selon ColumnConflict :
				- Suffix   : conserve les deux versions, suffixees _F1 et _F2.
				- PreferF1 : une seule colonne, valeur du fichier 1 privilegiee.
				- PreferF2 : une seule colonne, valeur du fichier 2 privilegiee.
			En mode PreferF1/PreferF2, ConflictEmptyValue regle le cas ou la valeur privilegiee
			est vide : Strict (on garde la valeur privilegiee, meme vide) ou Fallback (on prend
			l'autre fichier). La resolution est confiee a Resolve-ConflictValue.

			Si AddSource, ajoute SourceFileF1 / SourceFileF2.
		#>
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory=$true)][PSCustomObject]$Row1,
			[Parameter(Mandatory=$false)][PSCustomObject]$Row2,
			[Parameter(Mandatory=$true)][string[]]$Cols1,
			[Parameter(Mandatory=$true)][AllowEmptyCollection()][string[]]$Cols2,
			[Parameter(Mandatory=$true)][System.Collections.Generic.HashSet[string]]$CollisionSet,
			[Parameter(Mandatory=$true)][string]$KeyFile2,
			[Parameter(Mandatory=$true)][ValidateSet('Suffix','PreferF1','PreferF2')][string]$ColumnConflict,
			[Parameter(Mandatory=$true)][ValidateSet('Strict','Fallback')][string]$ConflictEmptyValue,
			[Parameter(Mandatory=$true)][bool]$AddSource,
			[Parameter(Mandatory=$true)][string]$Path1,
			[Parameter(Mandatory=$true)][string]$Path2
		)

		Begin{}
		Process{
			$NewRow = [ordered]@{}

			# --- Colonnes du fichier 1 ---
			foreach($Col in $Cols1){
				if($CollisionSet.Contains($Col)){
					# Colonne en collision : le traitement depend du mode ColumnConflict.
					if($ColumnConflict -eq 'Suffix'){
						# Mode historique : on conserve les deux versions, suffixe _F1 ici.
						$NewRow["$($Col)_F1"] = $Row1.$Col
					}else{
						# Modes PreferF1 / PreferF2 : on produit UNE seule colonne (nom d'origine),
						# resolue a partir des valeurs des deux fichiers. On la calcule ici, lors
						# du passage sur F1, pour preserver la position de la colonne. Le passage
						# sur F2 (plus bas) ignorera cette meme colonne pour ne pas la reecrire.
						$ValueF1 = $Row1.$Col
						# Row2 peut etre absent (non-match KeepUnmatched) -> valeur F2 consideree vide.
						$ValueF2 = if($null -ne $Row2){ $Row2.$Col } else { "" }

						$NewRow[$Col] = Resolve-ConflictValue -ValueF1 $ValueF1 -ValueF2 $ValueF2 -Preference $ColumnConflict -EmptyHandling $ConflictEmptyValue
					}
				}else{
					# Pas de collision : colonne propre a F1, reprise telle quelle.
					$NewRow[$Col] = $Row1.$Col
				}
			}

			# --- Colonnes du fichier 2 ---
			foreach($Col in $Cols2){
				# La cle F2 est ignoree (redondante avec la cle F1, deja presente).
				if($Col -eq $KeyFile2){
					continue
				}

				if($CollisionSet.Contains($Col)){
					# Colonne en collision.
					if($ColumnConflict -eq 'Suffix'){
						# Mode historique : on ajoute la version F2 suffixee.
						if($null -ne $Row2){
							$NewRow["$($Col)_F2"] = $Row2.$Col
						}else{
							$NewRow["$($Col)_F2"] = ""
						}
					}
					# Modes PreferF1 / PreferF2 : la colonne fusionnee a deja ete produite lors
					# du passage sur F1, on ne refait rien ici (eviter le doublon).
				}else{
					# Colonne propre a F2 : reprise telle quelle (vide si non-match).
					if($null -ne $Row2){
						$NewRow[$Col] = $Row2.$Col
					}else{
						$NewRow[$Col] = ""
					}
				}
			}

			if($AddSource){
				# En Join, SourceFileF1 toujours renseignee ; SourceFileF2 seulement si correspondance.
				$ValF2 = if($null -ne $Row2){ $Path2 } else { "" }
				$NewRow = Add-SourceColumns -Row $NewRow -ValueF1 $Path1 -ValueF2 $ValF2
			}

			return [PSCustomObject]$NewRow
		}
		End{}
	}

	Function Merge-Join{
		<#
		.SYNOPSIS
			Fusionne les lignes des deux jeux sur une cle (KeyFile1 = KeyFile2).
		.DESCRIPTION
			JoinType KeepUnmatched : conserve toutes les lignes du fichier 1.
			JoinType MatchedOnly   : ne conserve que les lignes avec correspondance.
			Les colonnes en collision (meme nom, hors cle) sont traitees selon ColumnConflict
			(Suffix par defaut, ou PreferF1 / PreferF2 avec gestion du vide ConflictEmptyValue).
			La comparaison des cles suit CaseSensitive (insensible a la casse par defaut).
			Retourne un objet avec : Merged (lignes fusionnees), NoMatchF1, NoMatchF2.
		#>
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory=$true)][AllowEmptyCollection()][PSCustomObject[]]$Rows1,
			[Parameter(Mandatory=$true)][AllowEmptyCollection()][PSCustomObject[]]$Rows2,
			[Parameter(Mandatory=$true)][string]$KeyFile1,
			[Parameter(Mandatory=$true)][string]$KeyFile2,
			[Parameter(Mandatory=$true)][string]$JoinType,
			[Parameter(Mandatory=$true)][bool]$CaseSensitive,
			[Parameter(Mandatory=$true)][string]$ColumnConflict,
			[Parameter(Mandatory=$true)][string]$ConflictEmptyValue,
			[Parameter(Mandatory=$true)][bool]$AddSource,
			[Parameter(Mandatory=$true)][string]$Path1,
			[Parameter(Mandatory=$true)][string]$Path2
		)

		Begin{}
		Process{
			$Merged    = New-Object System.Collections.Generic.List[PSCustomObject]
			$NoMatchF1 = New-Object System.Collections.Generic.List[PSCustomObject]
			$NoMatchF2 = New-Object System.Collections.Generic.List[PSCustomObject]

			# Sans lignes en F1, il n'y a rien a piloter : on sort avec des collections vides.
			if($Rows1.Count -eq 0){
				Write-LogEntry -Level 'WARNING' -Message "Mode Join : fichier 1 vide, rien a fusionner."
				return [PSCustomObject]@{ Merged = @(); NoMatchF1 = @(); NoMatchF2 = @() }
			}

			# Colonnes de chaque fichier, lues une seule fois (cache).
			$Cols1 = Get-ColumnNames -Rows $Rows1
			$Cols2 = Get-ColumnNames -Rows $Rows2

			# Collisions = colonnes presentes dans les deux fichiers, hors colonnes cles.
			# On stocke dans un HashSet pour des tests d'appartenance rapides dans Join-TwoRows.
			$CollisionCols = $Cols1 | Where-Object { ($Cols2 -contains $_) -and ($_ -ne $KeyFile1) -and ($_ -ne $KeyFile2) }
			$CollisionSet  = New-Object System.Collections.Generic.HashSet[string] (,[string[]]@($CollisionCols))
			if($CollisionSet.Count -gt 0){
				Write-LogEntry -Level 'INFO' -Message "Colonnes en collision suffixees _F1/_F2 : [$(@($CollisionCols) -join ', ')]."
			}

			# Comparateur coherent avec la regle de casse : il pilote a la fois l'index F2 et
			# le suivi des cles utilisees, garantissant que recherche et indexation s'accordent.
			$Comparer = Get-KeyComparer -CaseSensitive $CaseSensitive

			# Indexation du fichier 2 par sa cle. Une cle peut pointer plusieurs lignes (doublons F2).
			$Index2 = New-Object 'System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[PSCustomObject]]' ($Comparer)
			foreach($Row in $Rows2){
				$KeyValue = "$($Row.$KeyFile2)"
				if(-not $Index2.ContainsKey($KeyValue)){
					$Index2[$KeyValue] = New-Object System.Collections.Generic.List[PSCustomObject]
				}
				$Index2[$KeyValue].Add($Row)
			}

			# Suivi des cles F2 reellement appariees (meme comparateur de casse que l'index).
			$UsedKeysF2 = New-Object System.Collections.Generic.HashSet[string] ($Comparer)

			Write-LogEntry -Level 'INFO' -Message "Mode Join ($JoinType, CaseSensitive=$CaseSensitive) : indexation de $($Rows2.Count) ligne(s) du fichier 2 sur la cle '$KeyFile2'."

			# Parcours du fichier 1 : pour chaque ligne, on cherche ses correspondances dans l'index F2.
			foreach($Row1 in $Rows1){
				$KeyValue = "$($Row1.$KeyFile1)"
				$Matches  = if($Index2.ContainsKey($KeyValue)){ $Index2[$KeyValue] } else { $null }

				if($null -ne $Matches -and $Matches.Count -gt 0){
					# Correspondance trouvee : on fusionne F1 avec CHAQUE ligne F2 correspondante
					# (si F2 a des doublons sur la cle, on obtient plusieurs lignes en sortie).
					foreach($Row2 in $Matches){
						$Merged.Add( (Join-TwoRows -Row1 $Row1 -Row2 $Row2 -Cols1 $Cols1 -Cols2 $Cols2 -CollisionSet $CollisionSet -KeyFile2 $KeyFile2 -ColumnConflict $ColumnConflict -ConflictEmptyValue $ConflictEmptyValue -AddSource $AddSource -Path1 $Path1 -Path2 $Path2) )
					}
					[void]$UsedKeysF2.Add($KeyValue)
				}else{
					# Aucune correspondance : la ligne F1 est tracee comme non-match.
					$NoMatchF1.Add($Row1)

					# En KeepUnmatched, on garde quand meme la ligne dans le resultat (colonnes F2 vides).
					if($JoinType -eq 'KeepUnmatched'){
						$Merged.Add( (Join-TwoRows -Row1 $Row1 -Row2 $null -Cols1 $Cols1 -Cols2 $Cols2 -CollisionSet $CollisionSet -KeyFile2 $KeyFile2 -ColumnConflict $ColumnConflict -ConflictEmptyValue $ConflictEmptyValue -AddSource $AddSource -Path1 $Path1 -Path2 $Path2) )
					}
					# En MatchedOnly, la ligne sans correspondance est simplement exclue du resultat.
				}
			}

			# Lignes F2 dont la cle n'a jamais ete appariee a une ligne F1.
			foreach($Row2 in $Rows2){
				$KeyValue = "$($Row2.$KeyFile2)"
				if(-not $UsedKeysF2.Contains($KeyValue)){
					$NoMatchF2.Add($Row2)
				}
			}

			Write-LogEntry -Level 'INFO' -Message "Mode Join ($JoinType) : $($Merged.Count) ligne(s) fusionnee(s), $($NoMatchF1.Count) non-match F1, $($NoMatchF2.Count) non-match F2."

			return [PSCustomObject]@{
				Merged    = $Merged.ToArray()
				NoMatchF1 = $NoMatchF1.ToArray()
				NoMatchF2 = $NoMatchF2.ToArray()
			}
		}
		End{}
	}

	Function Invoke-Deduplication{
		<#
		.SYNOPSIS
			Applique la deduplication KeepFirst ou KeepLast sur le jeu de donnees.
		.DESCRIPTION
			En mode Join, la cle de deduplication est KeyColumn (la cle, eventuellement suffixee _F1).
			En mode Union (KeyColumn vide), la cle est la concatenation de toutes les colonnes.
			KeepFirst conserve la premiere occurrence rencontree, KeepLast la derniere.
		#>
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory=$true)][AllowEmptyCollection()][PSCustomObject[]]$Rows,
			[Parameter(Mandatory=$true)][ValidateSet('KeepFirst','KeepLast')][string]$Strategy,
			[Parameter(Mandatory=$false)][string]$KeyColumn
		)

		Begin{}
		Process{
			if($Rows.Count -eq 0){
				return ,@()
			}

			# IMPORTANT : on travaille sur une COPIE. [array]::Reverse modifie le tableau en place ;
			# sans copie, on inverserait le tableau de l'appelant (effet de bord indesirable).
			$Working = New-Object PSCustomObject[] ($Rows.Count)
			[System.Array]::Copy($Rows, $Working, $Rows.Count)

			# KeepLast : on parcourt a l'envers pour que la DERNIERE occurrence soit retenue en premier.
			if($Strategy -eq 'KeepLast'){
				[System.Array]::Reverse($Working)
			}

			$Seen   = New-Object System.Collections.Generic.HashSet[string]
			$Result = New-Object System.Collections.Generic.List[PSCustomObject]

			foreach($Row in $Working){
				# Construction de la cle de deduplication.
				if(-not [string]::IsNullOrWhiteSpace($KeyColumn)){
					# Mode Join : on se base sur la valeur de la colonne cle.
					$DedupKey = "$($Row.$KeyColumn)"
				}else{
					# Mode Union : pas de cle unique evidente, on concatene toutes les valeurs de la
					# ligne. On utilise une boucle foreach (plus rapide que ForEach-Object en pipeline).
					$Values = foreach($Property in $Row.PSObject.Properties){ "$($Property.Value)" }
					$DedupKey = $Values -join '|'
				}

				# HashSet.Add retourne $false si la cle existe deja : la ligne est alors un doublon.
				if($Seen.Add($DedupKey)){
					$Result.Add($Row)
				}
			}

			# Pour KeepLast, on a parcouru a l'envers : on remet l'ordre d'apparition d'origine.
			if($Strategy -eq 'KeepLast'){
				$Final = $Result.ToArray()
				[System.Array]::Reverse($Final)
				$ResultArray = $Final
			}else{
				$ResultArray = $Result.ToArray()
			}

			Write-LogEntry -Level 'INFO' -Message "Deduplication $Strategy : $($ResultArray.Count) ligne(s) conservee(s) sur $($Rows.Count)."
			return ,$ResultArray
		}
		End{}
	}

	Function Export-CSVData{
		<#
		.SYNOPSIS
			Exporte un jeu de donnees en CSV (cree un fichier vide si aucune ligne).
		#>
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory=$true)][AllowEmptyCollection()][PSCustomObject[]]$Rows,
			[Parameter(Mandatory=$true)][string]$FullPath,
			[Parameter(Mandatory=$true)][string]$Delimiter
		)

		Begin{}
		Process{
			# Jeu vide : on cree quand meme un fichier (vide) pour materialiser le resultat
			# (l'utilisateur sait que le traitement a eu lieu, pas de doute "plante ou rien a sortir ?").
			if($Rows.Count -eq 0){
				"" | Out-File -FilePath $FullPath -Encoding UTF8 -Force
				Write-LogEntry -Level 'INFO' -Message "Aucune ligne, fichier vide cree : '$FullPath'."
			}else{
				$Rows | Export-Csv -Path $FullPath -Delimiter $Delimiter -NoTypeInformation -Encoding UTF8 -Force
				Write-LogEntry -Level 'INFO' -Message "Fichier genere : '$FullPath' ($($Rows.Count) ligne(s))."
			}
		}
		End{}
	}
#endregion Fonctions de fusion

#region Principal
	Try{
		$CurrentScriptName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)

		Initialize-LogFile -LogFolder $OutputLog -ScriptFileName $CurrentScriptName

		# Le ParameterSet actif (Union ou Join) determine le mode : pas besoin d'un parametre dedie.
		$MergeMode = $PSCmdlet.ParameterSetName

		Write-LogEntry -Level 'INFO' -Message "=== Demarrage du script Merge-CSVFile (v$($Script:ScriptVersion)) ==="
		Write-LogEntry -Level 'INFO' -Message "Ordinateur : $($env:COMPUTERNAME)"
		Write-LogEntry -Level 'INFO' -Message "Utilisateur d'execution : $($env:USERDOMAIN)\$($env:USERNAME)"
		Write-LogEntry -Level 'INFO' -Message "Mode (ParameterSet) : $MergeMode"
		Write-LogEntry -Level 'INFO' -Message "InputCSV1 : $InputCSV1"
		Write-LogEntry -Level 'INFO' -Message "InputCSV2 : $InputCSV2"
		Write-LogEntry -Level 'INFO' -Message "Separateurs : F1='$InputDelimiter1', F2='$InputDelimiter2', sortie='$OutputDelimiter'."
		Write-LogEntry -Level 'INFO' -Message "AddSourceFileInfo : $($AddSourceFileInfo.IsPresent)"
		Write-LogEntry -Level 'INFO' -Message "Deduplicate : $Deduplicate"
		if(-not [string]::IsNullOrWhiteSpace($DeduplicateColumn)){
			Write-LogEntry -Level 'INFO' -Message "DeduplicateColumn : $DeduplicateColumn"
		}
		if($MergeMode -eq 'Union'){
			Write-LogEntry -Level 'INFO' -Message "StrictSchema : $($StrictSchema.IsPresent)"
		}else{
			Write-LogEntry -Level 'INFO' -Message "Cle de jointure : '$KeyFile1' (F1) = '$KeyFile2' (F2), JoinType=$JoinType, CaseSensitiveKey=$($CaseSensitiveKey.IsPresent)."
			Write-LogEntry -Level 'INFO' -Message "Resolution de collision : ColumnConflict=$ColumnConflict, ConflictEmptyValue=$ConflictEmptyValue."
			# Information : ConflictEmptyValue n'a d'effet qu'avec PreferF1 / PreferF2.
			if($ColumnConflict -eq 'Suffix' -and $ConflictEmptyValue -ne 'Strict'){
				Write-LogEntry -Level 'DEBUG' -Message "ConflictEmptyValue ignore en mode Suffix (pas de fusion de colonne)."
			}
			if(-not [string]::IsNullOrWhiteSpace($NoMatchOutputPath)){
				Write-LogEntry -Level 'INFO' -Message "Export des non-matchs vers : $NoMatchOutputPath."
			}
		}

		#region Verification des fichiers d'entree
			if(-not (Test-Path -LiteralPath $InputCSV1)){
				Write-LogEntry -Level 'ERROR' -Message "Fichier d'entree 1 introuvable (exit 2) : '$InputCSV1'."
				exit 2
			}
			if(-not (Test-Path -LiteralPath $InputCSV2)){
				Write-LogEntry -Level 'ERROR' -Message "Fichier d'entree 2 introuvable (exit 2) : '$InputCSV2'."
				exit 2
			}

			# Chemins complets, utilises pour la tracabilite source (colonnes SourceFileF1/F2).
			$FullPath1 = (Get-Item -LiteralPath $InputCSV1).FullName
			$FullPath2 = (Get-Item -LiteralPath $InputCSV2).FullName
		#endregion Verification des fichiers d'entree

		#region Verification du dossier de sortie
			Try{
				if(-not (Test-Path -LiteralPath $OutputPath)){
					Write-LogEntry -Level 'INFO' -Message "Le dossier de sortie n'existe pas, tentative de creation : '$OutputPath'."
					New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
					Write-LogEntry -Level 'INFO' -Message "Dossier de sortie cree."
				}else{
					Write-LogEntry -Level 'DEBUG' -Message "Le dossier de sortie existe deja."
				}

				# Dossier des non-matchs (uniquement en mode Join + option active).
				if($MergeMode -eq 'Join' -and -not [string]::IsNullOrWhiteSpace($NoMatchOutputPath)){
					if(-not (Test-Path -LiteralPath $NoMatchOutputPath)){
						New-Item -Path $NoMatchOutputPath -ItemType Directory -Force | Out-Null
						Write-LogEntry -Level 'INFO' -Message "Dossier des non-matchs cree : '$NoMatchOutputPath'."
					}
				}
			}Catch{
				Write-LogEntry -Level 'ERROR' -Message "Chemin de sortie inaccessible (exit 1) : $($_.Exception.Message)"
				exit 1
			}
		#endregion Verification du dossier de sortie

		#region Lecture des CSV
			Try{
				$Rows1 = Import-CSVFile -Path $InputCSV1 -Delimiter $InputDelimiter1
				$Rows2 = Import-CSVFile -Path $InputCSV2 -Delimiter $InputDelimiter2
			}Catch{
				Write-LogEntry -Level 'ERROR' -Message "Erreur de lecture des CSV (exit 3) : $($_.Exception.Message)"
				exit 3
			}
		#endregion Lecture des CSV

		#region Controle de schema (mode Union -StrictSchema)
			# En empilement strict, on refuse de fusionner si les deux fichiers n'ont pas
			# exactement les memes colonnes : c'est un garde-fou pour les fichiers censes etre homogenes.
			if($MergeMode -eq 'Union' -and $StrictSchema.IsPresent){
				$Cols1 = Get-ColumnNames -Rows $Rows1
				$Cols2 = Get-ColumnNames -Rows $Rows2
				$SchemaCheck = Test-SameSchema -Cols1 $Cols1 -Cols2 $Cols2

				if(-not $SchemaCheck.IsSame){
					Write-LogEntry -Level 'ERROR' -Message "StrictSchema : schemas incompatibles (exit 2)."
					if($SchemaCheck.OnlyInF1.Count -gt 0){
						Write-LogEntry -Level 'ERROR' -Message "Colonnes uniquement dans F1 : [$($SchemaCheck.OnlyInF1 -join ', ')]."
					}
					if($SchemaCheck.OnlyInF2.Count -gt 0){
						Write-LogEntry -Level 'ERROR' -Message "Colonnes uniquement dans F2 : [$($SchemaCheck.OnlyInF2 -join ', ')]."
					}
					exit 2
				}
				Write-LogEntry -Level 'INFO' -Message "StrictSchema : les deux fichiers ont les memes colonnes, empilement autorise."
			}
		#endregion Controle de schema

		#region Fusion
			if($MergeMode -eq 'Union'){
				$Merged    = Merge-Union -Rows1 $Rows1 -Rows2 $Rows2 -AddSource $AddSourceFileInfo.IsPresent -Path1 $FullPath1 -Path2 $FullPath2
				$NoMatchF1 = @()
				$NoMatchF2 = @()
			}else{
				$JoinResult = Merge-Join -Rows1 $Rows1 -Rows2 $Rows2 -KeyFile1 $KeyFile1 -KeyFile2 $KeyFile2 -JoinType $JoinType -CaseSensitive $CaseSensitiveKey.IsPresent -ColumnConflict $ColumnConflict -ConflictEmptyValue $ConflictEmptyValue -AddSource $AddSourceFileInfo.IsPresent -Path1 $FullPath1 -Path2 $FullPath2
				$Merged    = $JoinResult.Merged
				$NoMatchF1 = $JoinResult.NoMatchF1
				$NoMatchF2 = $JoinResult.NoMatchF2
			}
		#endregion Fusion

		#region Deduplication
			if($Deduplicate -ne 'None'){
				# Determination de la colonne servant de cle de deduplication, par ordre de priorite :
				#   1. -DeduplicateColumn si fourni explicitement par l'utilisateur (Union ou Join).
				#   2. Sinon, en mode Join : la colonne cle de F1 (suffixee _F1 si elle etait en collision).
				#   3. Sinon (Union sans colonne precisee) : $null -> deduplication sur la ligne entiere.
				$DedupKeyColumn = $null
				$MergedCols     = if($Merged.Count -gt 0){ Get-ColumnNames -Rows $Merged } else { @() }

				if(-not [string]::IsNullOrWhiteSpace($DeduplicateColumn)){
					# L'utilisateur a designe une colonne : on verifie qu'elle existe reellement dans
					# le resultat fusionne, sinon on avertit et on retombe sur la ligne entiere.
					if($MergedCols -contains $DeduplicateColumn){
						$DedupKeyColumn = $DeduplicateColumn
						Write-LogEntry -Level 'INFO' -Message "Deduplication cible sur la colonne '$DeduplicateColumn'."
					}else{
						Write-LogEntry -Level 'WARNING' -Message "Colonne de deduplication '$DeduplicateColumn' absente du resultat. Deduplication sur ligne entiere."
					}
				}elseif($MergeMode -eq 'Join' -and $Merged.Count -gt 0){
					# Comportement par defaut en Join : deduplication sur la cle de F1.
					if($MergedCols -contains $KeyFile1){
						$DedupKeyColumn = $KeyFile1
					}elseif($MergedCols -contains "$($KeyFile1)_F1"){
						$DedupKeyColumn = "$($KeyFile1)_F1"
					}
				}

				$Merged = Invoke-Deduplication -Rows $Merged -Strategy $Deduplicate -KeyColumn $DedupKeyColumn
			}
		#endregion Deduplication

		#region Export du fichier fusionne
			Try{
				$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
				$FileName  = "MergedCSV_$Timestamp.csv"
				$FullPath  = Join-Path -Path $OutputPath -ChildPath $FileName

				Export-CSVData -Rows $Merged -FullPath $FullPath -Delimiter $OutputDelimiter
			}Catch{
				Write-LogEntry -Level 'ERROR' -Message "Echec de l'export CSV fusionne (exit 4) : $($_.Exception.Message)"
				exit 4
			}
		#endregion Export du fichier fusionne

		#region Export des non-matchs (mode Join + option active)
			if($MergeMode -eq 'Join' -and -not [string]::IsNullOrWhiteSpace($NoMatchOutputPath)){
				Try{
					# On reutilise le meme horodatage que le fichier fusionne pour relier les fichiers entre eux.
					$NoMatchF1Path = Join-Path -Path $NoMatchOutputPath -ChildPath "MergedCSV_$($Timestamp)_NoMatchF1.csv"
					$NoMatchF2Path = Join-Path -Path $NoMatchOutputPath -ChildPath "MergedCSV_$($Timestamp)_NoMatchF2.csv"

					Export-CSVData -Rows $NoMatchF1 -FullPath $NoMatchF1Path -Delimiter $OutputDelimiter
					Export-CSVData -Rows $NoMatchF2 -FullPath $NoMatchF2Path -Delimiter $OutputDelimiter
				}Catch{
					# Un echec sur les non-matchs ne doit pas invalider le resultat principal deja ecrit : on logue en WARNING.
					Write-LogEntry -Level 'WARNING' -Message "Echec de l'export des non-matchs : $($_.Exception.Message)"
				}
			}
		#endregion Export des non-matchs

		Write-LogEntry -Level 'INFO' -Message "=== Fin du script avec succes (exit 0) ==="
		exit 0
	}catch{
		Write-LogEntry -Level 'ERROR' -Message "Erreur generale non geree (exit 99) ligne $($_.InvocationInfo.ScriptLineNumber) : $($_.Exception.Message)"
		exit 99
	}
#endregion Principal