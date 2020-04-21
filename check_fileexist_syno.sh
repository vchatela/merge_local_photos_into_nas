## TODO :
## - Option to use either remote/NAS folder or local/pc folder (source_on_nas OR source_on_pc + dest_on_nas)
## - Why some found are not found in FOUND --- to be reproduced
## - manage multiple returns of already-copied
## - finish --reuse feature // validate behavior
## Comment faire du fait du comm -2 pour traiter les fichiers qu'on trouve déjà ??
##    => il faudrait (temporairement) retirer les fichiers du dossier en cours (/volume1/photo/Album...) des fichiers nas_hashlist*

displaytime() {
	local T=$1
	local D=$((T/60/60/24))
	local H=$((T/60/60%24))
	local M=$((T/60%60))
	local S=$((T%60))
	(( $D > 0 )) && printf '%d jours ' $D
	(( $H > 0 )) && printf '%d heures ' $H
	(( $M > 0 )) && printf '%d minutes ' $M
	(( $D > 0 || $H > 0 || $M > 0 )) && printf 'et '
	printf 'Durée : %d secondes\n' $S
}

check_syno_hostname(){
	if [[ "$HOSTNAME" != *"$synology_host"* ]]; then
		echo "ERROR : not on synology.."
		exit -2
	fi
}

prepare_logs(){
	mkdir -p "$log_folder"
	echo > $logfile
}

echo_verbose(){
	if [ $VERBOSE -eq 1 ]; then
		echo $1
	fi
}

echo_success(){
  echo -e "\e[32m$1\e[0m"
}

echo_copied(){
  echo -e "\e[38;5;82m$1\e[0m"
}

echo_found(){
  echo -e "\e[38;5;119m$1\e[0m"
}

echo_bold(){
  echo -e "\e[1m$1\e[0m"
}

echo_error(){
  echo -e "\e[91m----------- ERREUR -----------\n$1\e[0m"
}

echo_warning(){
  echo -e "\e[38;5;202m$1\e[0m"
}

echo_working(){
  echo -e "\e[33m$1\e[0m"
}

show_logs(){
	echo_verbose "## Compte rendu ##"
	if [ "$MODE" = test ]; then
		echo_bold "Manquantes : $count_missing"
	elif [ "$MODE" = copy ]; then
		echo_bold "Copiées : $count_copied"
		echo_bold "Non copiées : $count_found"
	elif [ "$MODE" = nas ]; then
		echo_verbose "Verifications des fichiers Hash .."
		hashlist_lines=`wc -l $hashlist | awk '{ print $1 }'`
		hashlist_with_filename_lines=`wc -l $hashlist_with_filename | awk '{ print $1 }'`
		echo_verbose "$hashlist_lines lignes dans $hashlist"
		echo_verbose "$hashlist_with_filename_lines lignes dans $hashlist_with_filename"
		if [ $hashlist_lines -ne $hashlist_with_filename_lines ]; then
			echo_error "nas_hashlists ne contient pas le même nombre de lignes..."
		fi
		# Pas plus de logs en mode NAS
		exit 0
	elif [ "$MODE" = duplicate ]; then
		# TODO
		echo "Photos dupliquées : TODO"
		echo "Photos totales dupliquées : TODO"
	fi
	if [ $force_logs -eq 1 ]; then
			cat $logfile
	else
		while true; do
		    read -p "Voulez vous afficher les logs ? [Oui/Non]" on
		    case $on in
		        [Oo]* )  cat $logfile ; break;;
		        [Nn]* )  echo_success "Fichier ici : $logfile" ; break;;
		        * ) echo "Entrez Oui ou Non";;
		    esac
		done
	fi
	echo ""
}

make_hasfile_folder(){
	echo_verbose "------------- Creating Hashfile -------------"

	if [ $SHORT -eq 1 ]; then
		find "$source_dcim_folder" -type f -not -path '*@eaDir*' ! -name 'SYNO@.fileindexdb' ! -name 'Thumbs.db' ! -name '*.sort'  \( -name "*.png" -or -name "*.PNG" -or -name "*.jpeg" -or -name "*.jpg" -or -name "*.JPG" \) | head -$limit_find_output | xargs -d "\n" $xxh_location -H2 | sort | sed -r -e 's/^[a-zA-Z0-9]{32}/&\t/' > $hashlist_with_filename
	else
		find "$source_dcim_folder" -type f -not -path '*@eaDir*' ! -name 'SYNO@.fileindexdb' ! -name 'Thumbs.db' ! -name '*.sort'  \( -name "*.png" -or -name "*.PNG" -or -name "*.jpeg" -or -name "*.jpg" -or -name "*.JPG" \) -exec $xxh_location -H2 "{}" + | sort | sed -r -e 's/^[a-zA-Z0-9]{32}/&\t/' > $hashlist_with_filename
	fi
	#f370a6aaaa87714bb13d219f79058549  ./DSC_2876.JPG
	cat $hashlist_with_filename | awk '{print $1}' > $hashlist
	#f370a6aaaa87714bb13d219f79058549
}

make_uniq_hashfile_folder(){
	echo_verbose "------------- Creating Uniq Hashfile -------------"
	if [ "$1" == "nas" ]; then
		cat $nas_hashlist | sort | uniq > $nas_hashlist_uniq
	else
		cat $hashlist | sort | uniq > $hashlist_uniq
	fi
}

backup_nas_hashlists(){
	today_date="$1"
	echo "### Backup haslists nas ###"
	cp $nas_hashlist_with_filename $nas_hashlist_with_filename.$today_date
	cp $nas_hashlist $nas_hashlist.$today_date
	cp $nas_hashlist_uniq $nas_hashlist_uniq.$today_date
}

restore_nas_hashlists(){
	today_date="$1"
	echo "### Restoring haslists ###"
	echo "# Delete temp nas #"
	rm $nas_hashlist_with_filename
	rm $nas_hashlist
	rm $nas_hashlist_uniq

	echo "# Restoring olds nas #"
	mv $nas_hashlist_with_filename.$today_date $nas_hashlist_with_filename
	mv $nas_hashlist.$today_date $nas_hashlist
	mv $nas_hashlist_uniq.$today_date $nas_hashlist_uniq
}

update_hashfiles_from_sourcefolder(){
	## Si photos déplacées :
	# Avant
	#  f370a6aaaa87714bb13d219f79058549 /path/A/
	# A faire :
	# 1. Retirer ligne qui contient f370a6aaaa87714bb13d219f79058549
	# 2. Ajouter : f370a6aaaa87714bb13d219f79058549  /path/A/B

	while IFS="" read -r p || [ -n "$p" ]
	do
		old_file_location=$(grep "$p" $nas_hashlist_with_filename | awk -F"\t" '{print $2}' | xargs)
		new_file_location=$(grep "$p" $hashlist_with_filename | awk -F"\t" '{print $2}' | xargs)
		# Validation du sous dossier - Ex : old_file_location=/volume1/photo/Chargement Appareil Photo Val/toto.jpg
		# Déplacé en : new_file_location=/volume1/photo/Chargement Appareil Photo Val/Noël/toto.jpg
		# old_album_folder=/volume1/photo/Chargement Appareil Photo Val/Noël
		old_album_folder=`dirname "$old_file_location"`
		# old_file_location may not exists if it hasn't been scanned since the uploading
		if [ ! -z "$old_file_location" ]; then
			echo_verbose "new_file_location=$new_file_location -- old_file_location=$old_file_location"
			if [[ "$new_file_location" != *"$old_album_folder"* ]]; then
					echo_warning "Photo trouvée ailleurs que dans le sous dossier.. "
					echo_warning "Continue.."
			else
				# Remove lines with this hash $p
				sed -i '/$p/d' $nas_hashlist_with_filename
			fi
		fi
	done < $hashlist
	# Here $nas_hashlist_with_filename is cleaned with all hashes found on $hashlist

	# New lines are from source_folder so in hashlist_with_filename and hashlist
	# update nas_hashlist with those file
	cat $hashlist_with_filename >> $nas_hashlist_with_filename
	sort $nas_hashlist_with_filename > $nas_hashlist_with_filename
	cat $nas_hashlist_with_filename | awk '{print $1}' > $nas_hashlist
	cat $nas_hashlist | sort | uniq > $nas_hashlist_uniq

}

search_missing_photos(){
	if [ "$SOURCE_MODE" = "nas" ]; then
		## today_date defined above
		backup_nas_hashlists $today_date
		## Update hashfiles :
		### Add new location (files have probably been moved in order to migrate them)
		### Remove all files that are in the source_folder/dcim
		update_hashfiles_from_sourcefolder
	fi

	echo_verbose "------------- Search files in hashlist that are missing in nas_hashlist -------------"
	comm -23 $hashlist $nas_hashlist > $missing_hash_photos

	#if [ "$SOURCE_MODE" = "nas" ]; then

	#fi
	# restore_nas_hashfiles
	# TODO : do not (backup/)restore because file from source_folder will be moved -- so new location added later
}

prepare_destination_folder(){
	#Local/Remote dest preparation :
	cd "$path_to_tempphoto"
	mkdir -p "$path_album_name"
}

copy_missing_filenames(){
	dir=`dirname "$copied_hashlist"`
	album_name=`basename "$dir"`

	# Clean new hashlist to add
	echo "" > $temp_new_hash_for_nas_hashlist

	echo_verbose "------------- Copy missing files on NAS -------------"
	echo_working "Chargement de l'album : $album_name"
	echo_bold "## Photos copiées ##" >> $logfile
	while IFS="" read -r p || [ -n "$p" ]
	do
		missing_file=$(grep "$p" $hashlist_with_filename | awk -F"\t" '{print $2}' | xargs)
		if [ ! -f "$missing_file" ]; then
			echo_error "$missing_file non trouvé !"
			echo_error "$missing_file non trouvé !" >> $logfile
		else
			missing_short_file=`basename "$missing_file"`
			echo_copied "$missing_file : Copiée - $local_full_path_album/$missing_short_file" >> $logfile
			cp "$missing_file" "$local_full_path_album"
			mv "$missing_file" "$copied_folder"
			((count_copied++))
			#prepare for update_nas_hashlist_with_copied_files : which file in which final dest folder etc.
			# ex to insert : f370a6aaaa87714bb13d219f79058549  ./DSC_2876.JPG
			echo -e "$p\t$remote_full_path_album/$missing_short_file" >> $temp_new_hash_for_nas_hashlist
		fi
	done < $missing_hash_photos
}

update_nas_hashlist_with_copied_files(){
	echo_verbose "-------------- Ajout du nouveau Hashlist dans la référence du NAS ------------------"
	echo_verbose "Ajout dans hashlists"
	cat "$temp_new_hash_for_nas_hashlist" >> $nas_hashlist_with_filename
	cat "$temp_new_hash_for_nas_hashlist" | awk -F"\t" '{print $1}' >> $nas_hashlist

	echo_verbose "Copie de temp_hashlist dans album_folder"

	cp "$temp_new_hash_for_nas_hashlist" "$copied_hashlist"
	rm -f "$temp_new_hash_for_nas_hashlist"

	echo_verbose "Mise à jour du hashlist_uniq"
	make_uniq_hashfile_folder nas

	echo_verbose "Nettoyage des lignes vides dans les hashfiles"
	sed -i '/^$/d' $nas_hashlist_with_filename
	sed -i '/^$/d' $nas_hashlist
	sed -i '/^$/d' $nas_hashlist_uniq

	echo_verbose "Triage des hashlists"
	sort -o $nas_hashlist_with_filename $nas_hashlist_with_filename
	sort -o $nas_hashlist $nas_hashlist
}

show_location_already_copied_photos_on_nas(){
	echo_verbose "------------- Search files in hashlist that already exists in nas_hashlist -------------"
	comm -12 $hashlist $nas_hashlist > $already_copied_photos_hashlist
	extract_already_copied_location
}

extract_already_copied_location(){
	echo_verbose "------------- Already Copied files Locations -------------"
	echo_bold "## Photos déjà présentes ##" >> $logfile
	while IFS="" read -r p || [ -n "$p" ]
	do
		already_copied_file=$(grep "$p" $hashlist_with_filename | awk -F"\t" '{print $2}'  | xargs)
		nas_file_location=$(grep "$p" $nas_hashlist_with_filename | awk -F"\t" '{print $2}'  | xargs)

		nas_parent_album=${nas_file_location#*/photo/*}
		nas_parent_album=`dirname "$nas_parent_album"`
		## TODO
		# nas_file_location =
		# nas_parent_album =
		if [[ "$nas_file_location" == *"$nas_parent_album"* ]]; then
				# Dans le cas du déplacement d'un fichier depuis le NAS vers le NAS
				# on ignore
				echo_verbose "### Ignoring already found ###"
				continue
		fi
		echo_verbose "##$nas_parent_album##  - ##$##"
		# TODO : gérer plusieurs retours ....
		echo_found "$already_copied_file : Trouvée - $nas_file_location" >> $logfile
		# TODO : pour vérifier la taille, le fichier sur le NAS est ... sur le nas ! donc comment connaitre sa taille ?
		# Option 1 : la création nas_hashlist donne la taille du fichier en 3ème colonne
		# Option 2 : le script move_tempphoto fait la comparaison car il est exécuté sur le NAS  --
				# Comparaison en locale : si même taille alors on va dire qu'il est forcément en double => INUTILE : car contourne ce qu'on veut faire via FOUND/ pour ne pas envoyer
		# => Option 1 pas le choix !
		# if [[ $(stat -c%s "$already_copied_file") -ne $(stat -c%s "$nas_file_location") ]];then
		# 		echo_verbose "Même hash mais pas la même taille des fichiers ... " >> $logfile
		# else
		# 		echo_verbose "Même hash et même taille de fichier -- semble vraiment identique." >> $logfile
		# fi
		((count_found++))
		mv "$already_copied_file" "$found_folder/"
	done < $already_copied_photos_hashlist
	if [ $count_found -eq 0 ]; then
		echo_copied "Aucune photo déjà trouvée." >> $logfile
	fi
}

search_duplicated_files(){
	# Read files in NAS
		# For each :
		## - if more than 1 occurence of hash
	## show the filenames
	echo_verbose "------------- Show missing files -------------"
	echo_bold "## Photos déjà présentes ##" >> $logfile
	while IFS="" read -r p || [ -n "$p" ]
	do
		instance_duplicated=$(grep -c "$p" $nas_hashlist)
		if [ $instance_duplicated -gt 1 ]; then
			grep "$p" $hashlist_with_filename | awk -F"\t" '{print $2}'  | xargs
			((count_duplicated++))
			((count_total_instance_duplicated+=$instance_duplicated))
		fi
	done < $nas_hashlist_uniq
}

############################### MAIN
start=`date +%s`
VERBOSE=0
SHORT=0
REUSE=0
force_logs=0
synology_host="synology"

while [ $# -gt 0 ]; do
	case "$1" in
		-h|"-?"|--help)
			shift
			echo "usage: $0 [--copy source album_name] [--test source album_name] [--duplicate] [--nas] [--log] [--verbose] [--short]"
			exit 0
			;;
		-c|--copy)
			MODE=copy
			if [[ "$HOSTNAME" == *"$synology_host"* ]]; then
				#echo_error "Synology source is not an available feature."
				#exit -3
				SOURCE_MODE="nas"
			else
				SOURCE_MODE="pc"
			fi
			if [ $REUSE -eq 1 ] && [ $# -lt 2 ] || [ $# -lt 3 ]; then
				echo '2 paramètres sont nécessaires : Dossier source des photos + Nom de l album de destination (peut être un chemin comme "Noël/Mon Super Noel" mais ne pas oublier d entourer de guillemets.)'
				echo 'Example : check_fileexist_syno.sh --copy /tmp/Photos a envoyer/ "Noël/Super Album - 25-12-19/"'
				exit -1
			else
				if [ $REUSE -eq 1 ]; then
					source_dcim_folder=$2
					echo_verbose "Using source_dcim_folder=$source_dcim_folder"
					echo_verbose "Reuse=$REUSE -- path_album_name already set to : $path_album_name"
					shift;
				else
					source_dcim_folder=$2
					echo_verbose "Using source_dcim_folder=$source_dcim_folder"
					path_album_name=$3
					echo_verbose "Using path_album_name=$path_album_name"
					shift;
					shift;
				fi
			fi
			shift;
			;;
		-t|--test)
			MODE=test
			if [ $# -lt 3 ]; then
				echo '2 paramètres sont nécessaires : Dossier source des photos + Nom de l album de destination (peut être un chemin comme "Noël/Mon Super Noel" mais ne pas oublier d entourer de guillemets.)'
				echo 'Example : check_fileexist_syno.sh --copy /tmp/Photos a envoyer/ "Noël/Super Album - 25-12-19/"'
				exit -1
			else
				source_dcim_folder=$2
				echo_verbose "Using source_dcim_folder=$source_dcim_folder"
				path_album_name=$3
				echo_verbose "Using path_album_name=$path_album_name"
			fi
			shift;
			shift;
			shift;
			;;
			-n|--nas)
				check_syno_hostname
				MODE=nas
				shift;
				;;
			-l|--log)
				force_logs=1
				shift;
				;;
			-s|--short)
				SHORT=1
				if [ $# -lt 2 ]; then
					echo_error '1 paramètre est nécessaire pour limiter les résultats'
					echo 'Example : check_fileexist_syno.sh --nas --short 100'
					exit -1
				else
					limit_find_output=$2
					echo_verbose "Using limit_find_output=$limit_find_output"
				fi
				shift;
				shift;
				;;
			-r|--reuse)
				check_syno_hostname
				REUSE=1
				album_correct=0
				# ex : pwd=/volume1/photo/Chargement Appareil Photo/Album/Noël 25-12-18/
				# il faut garder Album/Noël 25-12-18/
				current_pwd=`pwd`
				path_album_name=`current_pwd#*/photo/*/`
				while [ $album_correct -eq 0 ]; do
				    read -p "Confirmes tu que l'album est : $path_album_name?  [Oui/Non]" on
				    case $on in
				        [Oo]* )  album_correct=1;;
				        [Nn]* )  echo "Erreur : merci de retirer --reuse / -r" ; exit -2;;
				        * ) echo "Entrez Oui ou Non";;
				    esac
				done
				echo_verbose "Using path_album_name=$path_album_name"
				shift;
				;;
		-v|--verbose)
			VERBOSE=1
			shift;
			;;
		-d|--duplicate)
			MODE=duplicate
			count_duplicated=0
			count_total_instance_duplicated=0
			search_duplicated_files
			# TODO : show log -- which file - where etc.
			exit 0
			;;
		*)
			echo_error "Error: unknown option '$1'"
			exit 1
			;;
	esac
done


## Variable definition
if [[ "$HOSTNAME" == *"$synology_host"* ]]; then
		prefix_path_syno_drive="/volume1/"
else
		prefix_path_syno_drive="/mnt/d/Syno/"
fi
xxh_location="$prefix_path_syno_drive/tools/photos/xxHash-0.7.3/xxhsum"
path_to_tempphoto="$prefix_path_syno_drive/temp_photos"
path_to_script_folder="$prefix_path_syno_drive/tools/photos/merge_local_photos_into_nas"
path_to_remote_photo="/volume1/photo"

log_folder="$path_to_script_folder/script_logs/"
hashfile_location="$path_to_script_folder/hashfiles"

if [ "$MODE" = copy ] || [ "$MODE" = test ]; then
	## Checks
	if [ ! -d "$source_dcim_folder" ]; then
		echo_error "$source_dcim_folder folder not found!"
		exit -1
	else
		copied_folder="$source_dcim_folder/Copied"
		found_folder="$source_dcim_folder/Found"
		# TODO : verify if those files already exists before requesting to delete them
		if [ ! -d "$copied_folder" ]; then
			mkdir "$copied_folder"
		else
			if [ $(ls -1 "$copied_folder" | wc -l) -ne 0 ]; then
				echo_warning "Fichier trouvés dans $copied_folder..."
				ls -l "$copied_folder"
				while true; do
				    read -p "Veux tu nettoyer le dossier $copied_folder?  [Oui/Non]" on
				    case $on in
				        [Oo]* )  rm "$copied_folder"/*  ; break;;
				        [Nn]* )  break;;
				        * ) echo "Entrez Oui ou Non";;
				    esac
				done
			fi
		fi
		if [ ! -d "$found_folder" ]; then
			mkdir "$found_folder"
		else
			if [ $(ls -1 "$found_folder" | wc -l) -ne 0 ]; then
				echo_warning "Fichier trouvés dans $found_folder..."
				ls -l "$found_folder"
				while true; do
				    read -p "Veux tu nettoyer le dossier $found_folder?  [Oui/Non]" on
				    case $on in
				        [Oo]* )  rm "$found_folder"/*  ; break;;
				        [Nn]* )  break;;
				        * ) echo "Entrez Oui ou Non";;
				    esac
				done
			fi
		fi
	fi
	# Local prefix can be on /mnt/d or already on the NAS
	local_full_path_album="$path_to_tempphoto/$path_album_name"
	remote_full_path_album="$path_to_remote_photo/$path_album_name"
	copied_hashlist="$local_full_path_album/copied_hashlist.hash"


	if [ -d "$local_full_path_album" ]; then
		echo_warning "Le dossier $local_full_path_album existe déjà. Les photos seront ajoutées"
	fi

	hashlist_with_filename="$hashfile_location/dcim_hashlist_with_filename.hash"
	hashlist="$hashfile_location/dcim_hashlist.hash"
	nas_hashlist="$hashfile_location/nas_hashlist.hash"
	nas_hashlist_with_filename="$hashfile_location/nas_hashlist_with_filename.hash"
	nas_hashlist_uniq="$hashfile_location/nas_hashlist_uniq.hash"
	already_copied_photos_hashlist="$hashfile_location/already_copied_photos_hashlist.hash"
	missing_hash_photos="$hashfile_location/missing_hash_photos.hash"
else if [ "$MODE" = nas ]; then
		source_dcim_folder="$path_to_remote_photo"
		hashlist_with_filename="$hashfile_location/nas_hashlist_with_filename.hash"
		hashlist="$hashfile_location/nas_hashlist.hash"
		hashlist_uniq="$hashfile_location/nas_hashlist_uniq.hash"
	else
		echo_error "Mode=$MODE unrecognized"
		exit -2
	fi

fi


today_date=`date +"%FT%H%M%S"`
logfile=$log_folder/$today_date.log
temp_new_hash_for_nas_hashlist=$log_folder/.tmp_nas_hashlist_$today_date.log
count_copied=0
count_found=0
count_missing=0

echo_verbose "------------- Working on $HOSTNAME -------------"
prepare_logs
# Create hash_list for NAS or Computer
echo_verbose "source_dcim_folder=$source_dcim_folder"
make_hasfile_folder
# If NAS then create uniq list


# If computer then compare and copy missings to new dest folder
if [ "$MODE" = nas ]; then
	make_uniq_hashfile_folder
elif [ "$MODE" = copy ] || [ "$MODE" = test ]; then

	prepare_destination_folder
	search_missing_photos
	if [ "$MODE" = copy ]; then
		copy_missing_filenames
		show_location_already_copied_photos_on_nas
		update_nas_hashlist_with_copied_files
		elif [ "$MODE" = test ]; then
			show_location_already_copied_photos_on_nas
		elif [ "$MODE" = duplicate ]; then
			continue
	fi
fi

end=`date +%s`
runtime=$((end-start))
displaytime $runtime

show_logs
