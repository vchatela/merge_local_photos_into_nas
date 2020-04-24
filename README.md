# Fonctionalités 
## Depuis PC
- [x] Chargement des photos depuis un PC vers le NAS -- uniquement des photos non présentes sur le NAS : *check_fileexist_syno.sh --copy*
- [x] Simuler/Afficher quelles photos aurait été chargée -- lesquelles ne sont pas sur le NAS : *check_fileexist_syno.sh --test*
- [ ] Réutiliser le nom du dossier de chargement comme nom d'album final : *check_fileexist_syno.sh --reuse*

## Depuis NAS
- [x] Créer un index de toutes les photos présentes sur le NAS : *check_fileexist_syno.sh --nas*
- [x] Rangement des albums chargés depuis le PC avec mise à jour du référentiel : *move_tempphoto_to_photo.sh*
- [x] Réindéxation pour éviter les incohérences sur Photos Stations : *syno_reindex.sh*
- [x] Possibilité d'éviter la réindéxation (par ex si plusieurs opérations) : *check_fileexist_syno.sh --block-reindex*

## Depuis PC ou NAS indépendement
- [x] Afficher les photos dupliquées et leurs emplacements sur le NAS : *check_fileexist_syno.sh --duplicate*
- [x] Mettre de côté les photos d'un album qui existent déjà ailleurs sur le NAS : *check_fileexist_syno.sh --move_duplicated*
- [ ] Gestion de l'upload et de la gestion des vidéos 

## Tests
- [x] 10 tests de validation du comportement attendus
- [ ] tests sur les fonctionnalités reuse, duplicate et move_duplicated

# Architecture
![Schéma Global](https://i.postimg.cc/brvmLmbf/merge-photos-into-nas.png)
## Pré-Configuration
### NAS - Dossier partagés sur Synology Drive
/photo : dossier racine avec tous les albums dedans  -- NON SYNC avec Syno Drive

/temp_photos : dossier qui sert de tampon avant d'être déplacé dans /photo pour limiter le nombre de photo synchroniser dans l'index Syno Drive -- SYNC

### Outils
Fonction de hashage rapide
Non cryptographique car pas besoin des propriétés de non réversibilité : [https:/github.com/Cyan4973/xxHash/](https:/github.com/Cyan4973/xxHash/)

Installation:
```
valentin@pc:/mnt/d/SynologyDrive/tools/photos/xxHash-0.7.3$ make
cc -O3    -c xxhash.c -o xxhash.o
ar rcs libxxhash.a xxhash.o
cc -O3  -fPIC   xxhash.c -shared -Wl,-soname=libxxhash.so.0 -o libxxhash.so.0.7.3
ln -sf libxxhash.so.0.7.3 libxxhash.so.0
ln -sf libxxhash.so.0.7.3 libxxhash.so
cc -O3    -c xxhsum.c -o xxhsum.o
cc -O3    xxhash.o xxhsum.o  -o xxhsum
ln -sf xxhsum xxh32sum
ln -sf xxhsum xxh64sum
ln -sf xxhsum xxh128sum
```
Attention ! Chaque nouvelle version de la librairie change le calcul des hashs.

Les actions nécessaires en cas de mise à jour :

1. Rajouter les nouvelles valeurs de hash dans les fichiers de tests
```
$ find /mnt/d/Syno/tools/photos/merge_local_photos_into_nas/sources_test -type f -type f -not -path '*@eaDir*' ! -name 'SYNO@.fileindexdb' ! -name 'Thumbs.db' ! -name '*.sort' \( -name "*.png" -or -name "*.PNG" -or -name "*.jpeg" -or -name "*.jpg" -or -name "*.JPG" \) -exec /mnt/d/Syno/tools/photos/xxHash-0.7.2/xxhsum -H2 "{}" + | sort | sed -r -e 's/^[a-zA-Z0-9]{32}/&\t/'
3c079ec2b7095f3f05c786ad89edc14c          /mnt/d/Syno/tools/photos/merge_local_photos_into_nas/sources_test/photo3.png
62f599af1fc5ed02f4a0ba23076c0d9e          /mnt/d/Syno/tools/photos/merge_local_photos_into_nas/sources_test/photo1.png
a4c3374cb47c8ccb88032a7db564330f          /mnt/d/Syno/tools/photos/merge_local_photos_into_nas/sources_test/photo2.png

$ find /mnt/d/Syno/tools/photos/merge_local_photos_into_nas/sources_test -type f -type f -not -path '*@eaDir*' ! -name 'SYNO@.fileindexdb' ! -name 'Thumbs.db' ! -name '*.sort' \( -name "*.png" -or -name "*.PNG" -or -name "*.jpeg" -or -name "*.jpg" -or -name "*.JPG" \) -exec /mnt/d/Syno/tools/photos/xxHash-0.7.3/xxhsum -H2 "{}" + | sort | sed -r -e 's/^[a-zA-Z0-9]{32}/&\t/'
12b9ef0f6f899ba279911d838a5daa3e          /mnt/d/Syno/tools/photos/merge_local_photos_into_nas/sources_test/photo1.png
a09a7a222b94bbdf5618a18dda32e66c          /mnt/d/Syno/tools/photos/merge_local_photos_into_nas/sources_test/photo3.png
aa7b076cbac4bceb352cfa3d084be34f          /mnt/d/Syno/tools/photos/merge_local_photos_into_nas/sources_test/photo2.png
```

2. Modifier dans test_check_fileexist.sh , check_fileexist_syno.sh et dans move_tempphoto_to_photo.sh les nouveaux chemins de xxh_location.
```
xxh_location=/mnt/d/Syno/tools/photos/xxHash-0.7.3/xxhsum
..
xxh_location=/volume1/tools/photos/xxHash-0.7.3/xxhsum
```
3. Relancer l'indexation avec le nouvel algorithme
```
admin@synology:~$ /volume1/tools/photos/merge_local_photos_into_nas/check_fileexist_syno.sh --nas --log
```

### Synology Drive PC
Montage de /temp_photos dans D:\Syno\temp_photos
Montage de /tools dans D:\Syno\tools

### Bash sur Windows 10
Accès de D:\Syno\tools depuis /mnt/d/Syno/tools

### Astuce montage SD (bash W10)
```
valentin@pc:/mnt/d/Syno/tools/photos/merge_local_photos_into_nas/$ cat mount_sd_h.sh
sudo mkdir -p /mnt/h
sudo mount -t drvfs H: /mnt/h
# Lancement de la fonction $1 (copy OU test) et $2 le nom de l'album (peut être un chemin avec les /)
/mnt/d/Syno/tools/photos/merge_local_photos_into_nas/check_fileexist_syno.sh --$1 /mnt/h/DCIM/100D5300/ "$2"

valentin@pc:/mnt/d/Syno/tools/photos/merge_local_photos_into_nas/$./mount_sd_h.sh test "Noël/Test 01-01-01"
...
```

## Scripts
### check_fileexist_syno.sh
#### Fonctionnement sur NAS
Création de 3 fichiers (en environ 2h pour 42k photos)
```
# nas_hashlist_with_filename.hash
...
0000f3449315e7620a875c32610e0cf0	  /volume1/photo/Puy du Fou - 19-07-17/20170718-223429.jpg
00011072d9b6a85caa33f2e8a9d65535	  /volume1/photo/Anniversaires/Céline 06-2012/303626_4061160969724_126076403_n.jpg
...
# nas_hashlist.hash
...
0000f3449315e7620a875c32610e0cf0
00011072d9b6a85caa33f2e8a9d65535
...
# nas_hashlist_uniq.hash
...
0000f3449315e7620a875c32610e0cf0
00011072d9b6a85caa33f2e8a9d65535
...
# nas_hashlist_duplicated.hash
0000f3449315e7620a875c32610e0cf0
00011072d9b6a85caa33f2e8a9d65535
...
```
#### Fonctionnement sur Serveur
Création de 2 fichiers :
```
# dcim_hashlist_with_filename.hash
3c079ec2b7095f3f05c786ad89edc14c	  /tmp/test_copy_photos/photo3.png
62f599af1fc5ed02f4a0ba23076c0d9e	  /tmp/test_copy_photos/photo1.png
a4c3374cb47c8ccb88032a7db564330f	  /tmp/test_copy_photos/photo2.png

# dcim_hashlist.hash
3c079ec2b7095f3f05c786ad89edc14c	  
62f599af1fc5ed02f4a0ba23076c0d9e	  
a4c3374cb47c8ccb88032a7db564330f	  
```
### move_tempphoto_to_photo.sh
Déplacement depuis /temp_photos vers /photos.

Comme il est impossible de savoir si la photo a été totalement envoyée/chargée au moment du lancement du script, on utilisera la fonction de hashage pour s'assurer de l'ingrité des fichiers présents.

Au moment de l'envoi l'empreinte est rajoutée dans un fichier qui est ajouté dans le dossier temp_photo/$album_name.
```
~$ /volume1/photo/album_photo_rights_to_be_reviewed.txt
## Mon Apr 13 15:15:00 CEST 2020
/volume1/photo/Mon album 1

~$ Copied Hashlist : /mnt/d/Syno/temp_photos/Test - 01-01-01/copied_hashlist.hash

12b9ef0f6f899ba279911d838a5daa3e        /volume1/photo/Test - 01-01-01/photo1.png
aa7b076cbac4bceb352cfa3d084be34f        /volume1/photo/Test - 01-01-01/photo2.png
```
## Post-Configuration NAS
### Tâches planifiées
#### Générer hashlists (chaque 3 jours)
```
/volume1/tools/photos/merge_local_photos_into_nas/check_fileexist_syno.sh
```
#### Déplacer photos (toutes les 1h)
```
/volume1/tools/photos/merge_local_photos_into_nas/move_tempphoto_to_photo.sh
```
# Utilisations      
Création de l'indexation sur le NAS
```
admin@synology:~$ /volume1/tools/photos/merge_local_photos_into_nas/check_fileexist_syno.sh --nas
```
Envoi vers l'album 1
```
valentin@pc:/mnt/d/Syno/tools/photos/merge_local_photos_into_nas/$ ./clean_photos.sh && /mnt/d/Syno/tools/photos/merge_local_photos_into_nas/check_fileexist_syno.sh --copy /tmp/test_copy_photos/ "Mon album 1" --log
Chargement de l'album : Mon album 1
Durée : 1 secondes
Copiées : 3
Non copiées : 0

## Photos copiées ##
/tmp/test_copy_photos/photo1.png : Copiée - /mnt/d/Syno/temp_photos/Mon album 1/photo1.png
/tmp/test_copy_photos/photo3.png : Copiée - /mnt/d/Syno/temp_photos/Mon album 1/photo3.png
/tmp/test_copy_photos/photo2.png : Copiée - /mnt/d/Syno/temp_photos/Mon album 1/photo2.png
## Photos déjà présentes ##
Aucune photo déjà trouvée.
```
Simulation de l'envoi pour détecter les photos déjà présentes
```
valentin@pc:/mnt/d/Syno/tools/photos/merge_local_photos_into_nas/$ /mnt/d/Syno/tools/photos/merge_local_photos_into_nas/check_fileexist_syno.sh --test /tmp/test_copy_photos/ "Mon album 1" --log
...
```
Tâche automatique de rangement des photos sur le NAS
```
admin@synology:~$ /volume1/tools/photos/merge_local_photos_into_nas/move_tempphoto_to_photo.sh
Exécution du : Tue Apr 14 23:18:07 CEST 2020
-----
Album : Mon album 1
Toutes les photos déplacées

----------- Permissions à donner -----------
-- Fichier des permissions : /volume1/photo/album_photo_rights_to_be_reviewed.txt
## Mon Apr 13 15:15:00 CEST 2020
/volume1/photo/Mon album 1
```

# Tests      
## Test_check_fileexist.sh
### Test PC
#### Test 1 : Envoi de 3 photos
```
## Test 1 ##
## Run script ##
Chargement de l'album : Test - 01-01-01
Durée : 1 secondes
Copiées : 3
Non copiées : 0

## Photos copiées ##
/tmp/test_copy_photos/photo1.png : Copiée - /mnt/d/Syno/temp_photos/Test - 01-01-01/photo1.png
/tmp/test_copy_photos/photo3.png : Copiée - /mnt/d/Syno/temp_photos/Test - 01-01-01/photo3.png
/tmp/test_copy_photos/photo2.png : Copiée - /mnt/d/Syno/temp_photos/Test - 01-01-01/photo2.png
## Photos déjà présentes ##
Aucune photo déjà trouvée.

### Verify NAS Hashlist ###
Result : 0
## Cleanup ##
test1 success
```
#### Test 2 : Envoi de 3 photos dont 1 déjà présente (fake insertion dans le nas_hashlist)
```
## Run script ##
Chargement de l'album : Test - 01-01-01
Durée : 1 secondes
Copiées : 2
Non copiées : 1

## Photos copiées ##
/tmp/test_copy_photos/photo1.png : Copiée - /mnt/d/Syno/temp_photos/Test - 01-01-01/photo1.png
/tmp/test_copy_photos/photo2.png : Copiée - /mnt/d/Syno/temp_photos/Test - 01-01-01/photo2.png
## Photos déjà présentes ##
/tmp/test_copy_photos/photo3.png : Trouvée - /mnt/d/Syno/temp_photos/Test - 01-01-01/photo3.png

### Verify NAS Hashlist ###
Result : 0
## Cleanup ##
test2 success
```
#### Test 3 : Vérification du fichier copied_hashlist utilisé pour s'assurer du téléchargement complet
```
## Test 3 ##
## Run script ##
Chargement de l'album : Test - 01-01-01
Durée : 4 secondes
Copiées : 2
Non copiées : 0

## Photos copiées ##
/tmp/test_copy_photos/photo1.png : Copiée - /mnt/d/Syno/temp_photos/Test - 01-01-01/photo1.png
/tmp/test_copy_photos/photo2.png : Copiée - /mnt/d/Syno/temp_photos/Test - 01-01-01/photo2.png
## Photos déjà présentes ##
Aucune photo déjà trouvée.

### Verify Copied Hashlist ###
Copied Hashlist : /mnt/d/Syno/temp_photos/Test - 01-01-01/copied_hashlist.hash
Result : 0
## Cleanup ##
test3 success
```
#### Test 4 : Validation de la fonction de test
```
TODO
```
### Test NAS
#### Test 5 : Création du référentiel (sur seulement 50 éléments)
```
### Backup haslists ###
Using limit_find_output=50
------------- Working on synology -------------
source_dcim_folder=/volume1/photo/
------------- Creating Hashfile -------------
------------- Creating Uniq Hashfile -------------
Durée : 2 secondes
## Compte rendu ##
Verifications des fichiers Hash ..
50 lignes dans /volume1/tools/photos/merge_local_photos_into_nas/hashfiles/nas_hashlist.hash
50 lignes dans /volume1/tools/photos/merge_local_photos_into_nas/hashfiles/nas_hashlist_with_filename.hash
##### hashlist_with_filename contenu #####
show only 10
01b23cf16b0c49ce682a1f766a55cf99          /volume1/photo/Amour/received_m_mid_1409213635892_8eac44fa27e87f4494_0.jpeg
0cfc7e3a9a786863729a5bc6fc819017          /volume1/photo/Amour/received_m_mid_1409213644367_daaaa76fbc39806070_0.jpeg
0d5490b43b181ee8d80315faed53e366          /volume1/photo/Amour/2014-11-04 20.49.35.png
0faca534a7f2e1c972e8e4788ec8732d          /volume1/photo/Amour/2014-08-07 14.18.42.png
17d6fec028338db339b0144fc0e9e4a3          /volume1/photo/Amour/1437163047992.jpg
1a1057348ff81bb33af445dda0a37c51          /volume1/photo/Amour/Screenshot_2015-12-13-13-04-23.png
1db0133dd5d456f7f64a0a3117590f99          /volume1/photo/Amour/Snapchat-2050228820.jpg
28df2930bf4309b0b3a394120200a120          /volume1/photo/Amour/Snapchat--2348499473992816667.jpg
3c6221534ce0b834a0988c47e6186fdb          /volume1/photo/Amour/2015-01-11 13.56.54-8.jpg
3d73c232f7107d54810ff25cb9b70663          /volume1/photo/Amour/Snapchat-782347623.jpg
##### Hashlist contenu #####
show only 10
01b23cf16b0c49ce682a1f766a55cf99
0cfc7e3a9a786863729a5bc6fc819017
0d5490b43b181ee8d80315faed53e366
0faca534a7f2e1c972e8e4788ec8732d
17d6fec028338db339b0144fc0e9e4a3
1a1057348ff81bb33af445dda0a37c51
1db0133dd5d456f7f64a0a3117590f99
28df2930bf4309b0b3a394120200a120
3c6221534ce0b834a0988c47e6186fdb
3d73c232f7107d54810ff25cb9b70663
### Restoring haslists ###
# Delete temp #
# Restoring olds #
test5 success
```
#### Test 6 : Validation de la copie depuis un dossier du NAS vers un autre dossier du NAS
```
## Test 6 ##
synology_vc
## Run script ##
Using source_dcim_folder=/tmp/test_copy_photos/
Using path_album_name=Test - 01-01-01
------------- Working on synology_vc -------------
source_dcim_folder=/tmp/test_copy_photos/
------------- Creating Hashfile -------------
### Backup haslists nas ###
------------- Search files in hashlist that are missing in nas_hashlist -------------
------------- Copy missing files on NAS -------------
Chargement de l'album : Test - 01-01-01
------------- Search files in hashlist that already exists in nas_hashlist -------------
------------- Already Copied files Locations -------------
-------------- Ajout du nouveau Hashlist dans la référence du NAS ------------------
Ajout dans hashlists
Copie de temp_hashlist dans album_folder
Mise à jour du hashlist_uniq
------------- Creating Uniq Hashfile -------------
Nettoyage des lignes vides dans les hashfiles
Triage des hashlists
Durée : 1 secondes
## Compte rendu ##
Copiées : 2
Non copiées : 0

## Photos copiées ##
/tmp/test_copy_photos/photo1.png : Copiée - /volume1//temp_photos/Test - 01-01-01/photo1.png
/tmp/test_copy_photos/photo2.png : Copiée - /volume1//temp_photos/Test - 01-01-01/photo2.png
## Photos déjà présentes ##
Aucune photo déjà trouvée.

### Verify NAS Hashlist ###
Result : 0
## Cleanup ##
test6 success
```
#### Test 7 : Equivalent test 6 mais avec une arboresence pour l'album (Noël/2020/Mon Album)
```
## Test 7 ##
synology_vc
## Run script ##
Using source_dcim_folder=/tmp/test_copy_photos/
Using path_album_name=Test/Test - 01-01-01
------------- Working on synology_vc -------------
source_dcim_folder=/tmp/test_copy_photos/
------------- Creating Hashfile -------------
### Backup haslists nas ###
------------- Search files in hashlist that are missing in nas_hashlist -------------
------------- Copy missing files on NAS -------------
Chargement de l'album : Test - 01-01-01
------------- Search files in hashlist that already exists in nas_hashlist -------------
------------- Already Copied files Locations -------------
-------------- Ajout du nouveau Hashlist dans la référence du NAS ------------------
Ajout dans hashlists
Copie de temp_hashlist dans album_folder
Mise à jour du hashlist_uniq
------------- Creating Uniq Hashfile -------------
Nettoyage des lignes vides dans les hashfiles
Triage des hashlists
Durée : 0 secondes
## Compte rendu ##
Copiées : 2
Non copiées : 0

## Photos copiées ##
/tmp/test_copy_photos/photo1.png : Copiée - /volume1//temp_photos/Test/Test - 01-01-01/photo1.png
/tmp/test_copy_photos/photo2.png : Copiée - /volume1//temp_photos/Test/Test - 01-01-01/photo2.png
## Photos déjà présentes ##
Aucune photo déjà trouvée.

### Verify NAS Hashlist ###
Result : 0
## Cleanup ##
test7 success
```

#### Test 8 : TODO -- Validation du reuse / une fois feature terminée
```

```
#### Test 9 : Validation du script move_tempphoto_to_photo pour album simple
```
## Test 9 ##
synology_vc
## Run check_fileexist_syno : /volume1//tools/photos/merge_local_photos_into_nas/check_fileexist_syno.sh ##
Using source_dcim_folder=/tmp/test_copy_photos/
Using path_album_name=Test - 01-01-01
------------- Working on synology_vc -------------
source_dcim_folder=/tmp/test_copy_photos/
------------- Creating Hashfile -------------
### Backup haslists nas ###
------------- Search files in hashlist that are missing in nas_hashlist -------------
------------- Copy missing files on NAS -------------
Chargement de l'album : Test - 01-01-01
------------- Search files in hashlist that already exists in nas_hashlist -------------
------------- Already Copied files Locations -------------
-------------- Ajout du nouveau Hashlist dans la référence du NAS ------------------
Ajout dans hashlists
Copie de temp_hashlist dans album_folder
Mise à jour du hashlist_uniq
------------- Creating Uniq Hashfile -------------
Nettoyage des lignes vides dans les hashfiles
Triage des hashlists
Durée : 0 secondes
## Compte rendu ##
Copiées : 2
Non copiées : 0

## Photos copiées ##
/tmp/test_copy_photos/photo1.png : Copiée - /volume1//temp_photos/Test - 01-01-01/photo1.png
/tmp/test_copy_photos/photo2.png : Copiée - /volume1//temp_photos/Test - 01-01-01/photo2.png
## Photos déjà présentes ##
Aucune photo déjà trouvée.

## Run move_tempphoto_to_photo : /volume1//tools/photos/merge_local_photos_into_nas/move_tempphoto_to_photo.sh ##
Exécution du : Wed Apr 22 22:19:46 CEST 2020
album_copied_hashlist=/volume1/temp_photos/Test - 01-01-01/copied_hashlist.hash
-----
Album : Test - 01-01-01
Toutes les photos déplacées
album_copied_hashlist=
Result : 0
## Cleanup ##
test9 success
```
#### Test 10 : Validation du script move_tempphoto_to_photo pour arboresence album
```
## Test 10 ##
synology_vc
## Run check_fileexist_syno : /volume1//tools/photos/merge_local_photos_into_nas/check_fileexist_syno.sh ##
Using source_dcim_folder=/tmp/test_copy_photos/
Using path_album_name=Test/Test - 01-01-01
------------- Working on synology_vc -------------
source_dcim_folder=/tmp/test_copy_photos/
------------- Creating Hashfile -------------
### Backup haslists nas ###
------------- Search files in hashlist that are missing in nas_hashlist -------------
------------- Copy missing files on NAS -------------
Chargement de l'album : Test - 01-01-01
------------- Search files in hashlist that already exists in nas_hashlist -------------
------------- Already Copied files Locations -------------
-------------- Ajout du nouveau Hashlist dans la référence du NAS ------------------
Ajout dans hashlists
Copie de temp_hashlist dans album_folder
Mise à jour du hashlist_uniq
------------- Creating Uniq Hashfile -------------
Nettoyage des lignes vides dans les hashfiles
Triage des hashlists
Durée : 1 secondes
## Compte rendu ##
Copiées : 2
Non copiées : 0

## Photos copiées ##
/tmp/test_copy_photos/photo1.png : Copiée - /volume1//temp_photos/Test/Test - 01-01-01/photo1.png
/tmp/test_copy_photos/photo2.png : Copiée - /volume1//temp_photos/Test/Test - 01-01-01/photo2.png
## Photos déjà présentes ##
Aucune photo déjà trouvée.

## Run move_tempphoto_to_photo : /volume1//tools/photos/merge_local_photos_into_nas/move_tempphoto_to_photo.sh ##
Exécution du : Wed Apr 22 22:19:59 CEST 2020
album_copied_hashlist=/volume1/temp_photos/Test/Test - 01-01-01/copied_hashlist.hash
-----
Album : Test/Test - 01-01-01
Toutes les photos déplacées
Result : 0
## Cleanup ##
test10 success
```

# Notes techniques
## Fonction de hashage
Chaque changement de code implique un changement des hashs.
Recommandation : ne changer que si gain de performance significatif car nécessite de réindexer le NAS + adapter les scripts.

# Renommage
Vérifier si vaut mieux rename avant ou après envoi ?
- option 1 : rename avant l'envoi  --- nécessite exiftool en local + modif script de renommage pour fonctionner en local
- option 2 : laisser rename auto périodique
 =>dans tous les cas la duplication d'une photo est traitée par l'empreinte de la photo (pas son nom)

On laissera le script faire la maj et la réindexation en suivant
```
# Tâche planifiée tous les 3 jours
/volume1/tools/photos/merge_local_photos_into_nas/exiftool_rename_pictures.sh
/volume1/tools/photos/merge_local_photos_into_nas/check_fileexist_syno.sh --nas
```

# Réindexation
Deux moments où les photos sont déplcaes : --copy ou --move_duplicated
## Depuis le PC
Seul le --copy bouge des fichiers mais ils sont déplacés dans /temp_photo du coup on s'appuiera sur le move_tempphoto_to_photo.sh qui lui réindexera une fois les photos réellement déplacées.
## Depuis le NAS
Soit on réindexe à la fin directement, soit on sauvegarde dans *$syno_reindex_need_file* pour redemander plus tard.  