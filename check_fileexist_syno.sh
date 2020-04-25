## TODO :
## - Why some found are not found in FOUND --- to be reproduced
## - manage multiple returns of already-copied

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
	echo > "$logfile"
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
		hashlist_lines=`wc -l "$hashlist" | awk '{ print $1 }'`
		hashlist_with_filename_lines=`wc -l "$hashlist_with_filename" | awk '{ print $1 }'`
		echo_verbose "$hashlist_lines lignes dans $hashlist"
		echo_verbose "$hashlist_with_filename_lines lignes dans $hashlist_with_filename"
		if [ $hashlist_lines -ne $hashlist_with_filename_lines ]; then
			echo_error "nas_hashlists ne contient pas le même nombre de lignes..."
		fi
		# Pas plus de logs en mode NAS
		exit 0
	elif [ "$MODE" = duplicate ]; then
		# TODO
		echo "Photos dupliquées : $count_duplicated"
		echo "Photos totales dupliquées : $count_total_instance_duplicated"
	fi
	if [ $force_logs -eq 1 ]; then
			cat "$logfile"
	else
		while true; do
		    read -p "Voulez vous afficher les logs ? [Oui/Non]" on
		    case $on in
		        [Oo]* )  cat "$logfile" ; break;;
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
		find "$source_dcim_folder" -type f -not -path '*@eaDir*' ! -path "*#recycle*" ! -name 'SYNO@.fileindexdb' ! -name 'Thumbs.db' ! -name '*.sort'  \( -name "*.png" -or -name "*.PNG" -or -name "*.jpeg" -or -name "*.jpg" -or -name "*.JPG" \) | head -$limit_find_output | xargs -d "\n" "$xxh_location" -H2 | sort | sed -r -e 's/^[a-zA-Z0-9]{32}/&\t/' > "$hashlist_with_filename"
	else
		find "$source_dcim_folder" -type f -not -path '*@eaDir*' ! -path "*#recycle*" ! -name 'SYNO@.fileindexdb' ! -name 'Thumbs.db' ! -name '*.sort'  \( -name "*.png" -or -name "*.PNG" -or -name "*.jpeg" -or -name "*.jpg" -or -name "*.JPG" \) -exec "$xxh_location" -H2 "{}" + | sort | sed -r -e 's/^[a-zA-Z0-9]{32}/&\t/' > "$hashlist_with_filename"
	fi
	#f370a6aaaa87714bb13d219f79058549  ./DSC_2876.JPG
	cat "$hashlist_with_filename" | awk '{print $1}' > "$hashlist"
	#f370a6aaaa87714bb13d219f79058549
}

make_uniq_hashfile_folder(){
	echo_verbose "------------- Creating Uniq Hashfile -------------"
	if [ "$SOURCE_MODE" = "nas" ]; then
		cat "$nas_hashlist" | sort | uniq > "$nas_hashlist_uniq"
	else
		cat "$hashlist" | sort | uniq > "$hashlist_uniq"
	fi
}

make_duplicated_hashfile(){
	echo_verbose "------------- Creating Duplicated Hashfile -------------"
	uniq -d "$nas_hashlist" > "$nas_hashlist_duplicated"
}

backup_nas_hashlists(){
	today_date="$1"
	echo "### Backup haslists nas ###"
	cp "$nas_hashlist_with_filename" "$nas_hashlist_with_filename.$today_date"
	cp "$nas_hashlist" "$nas_hashlist.$today_date"
	cp "$nas_hashlist_uniq" "$nas_hashlist_uniq.$today_date"
	cp "$nas_hashlist_duplicated" "$nas_hashlist_duplicated.$today_date"
}

restore_nas_hashlists(){
	today_date="$1"
	echo "### Restoring haslists ###"
	echo "# Delete temp nas #"
	rm "$nas_hashlist_with_filename"
	rm "$nas_hashlist"
	rm "$nas_hashlist_uniq"
	rm "$nas_hashlist_duplicated"

	echo "# Restoring olds nas #"
	mv "$nas_hashlist_with_filename.$today_date" "$nas_hashlist_with_filename"
	mv "$nas_hashlist.$today_date" "$nas_hashlist"
	mv "$nas_hashlist_uniq.$today_date" "$nas_hashlist_uniq"
	mv "$nas_hashlist_duplicated.$today_date" "$nas_hashlist_duplicated"
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
		old_file_location=$(grep "$p" "$nas_hashlist_with_filename" | awk -F"\t" '{print $2}' | xargs -0)
		new_file_location=$(grep "$p" "$hashlist_with_filename" | awk -F"\t" '{print $2}' | xargs -0)
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
				# Remove lines with this hash
				remove_line_in_nashashlistwithfilename_from_hash "$p"
			fi
		fi
	done <<< "$hashlist"
	# Here $nas_hashlist_with_filename is cleaned with all hashes found on $hashlist

	# New lines are from source_folder so in hashlist_with_filename and hashlist
	# update nas_hashlist with those file
	cat "$hashlist_with_filename" >> "$nas_hashlist_with_filename"
	update_nas_hashlist_based_on_nashashlistwithfilename
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
	comm -23 "$hashlist" "$nas_hashlist" > "$missing_hash_photos"

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
	echo "" > "$temp_new_hash_for_nas_hashlist"

	echo_verbose "------------- Copy missing files on NAS -------------"
	echo_working "Chargement de l'album : $album_name"
	echo_bold "## Photos copiées ##" >> "$logfile"
	while IFS="" read -r p || [ -n "$p" ]
	do
		missing_file=$(grep "$p" "$hashlist_with_filename" | awk -F"\t" '{print $2}' | xargs -0)
		if [ ! -f "$missing_file" ]; then
			echo_error "$missing_file non trouvé !"
			echo_error "$missing_file non trouvé !" >> "$logfile"
		else
			missing_short_file=`basename "$missing_file"`
			echo_copied "$missing_file : Copiée - $local_full_path_album/$missing_short_file" >> "$logfile"
			cp "$missing_file" "$local_full_path_album"
			mv "$missing_file" "$copied_folder"
			if [ "$SOURCE_MODE" = "nas" ]; then
				syno_reindex_needed=1
			fi
			((count_copied++))
			#prepare for update_nas_hashlist_with_copied_files : which file in which final dest folder etc.
			add_line_in_nashashlistwithfilename "$p" "$remote_full_path_album/$missing_short_file"
			echo -e "$p\t$remote_full_path_album/$missing_short_file" >> "$temp_new_hash_for_nas_hashlist"
		fi
	done < "$missing_hash_photos"	
	echo_verbose "Copie de temp_hashlist dans album_folder"
	cp "$temp_new_hash_for_nas_hashlist" "$copied_hashlist"
	rm "$temp_new_hash_for_nas_hashlist"
	update_nas_hashlist_based_on_nashashlistwithfilename
}

add_line_in_nashashlistwithfilename(){
	# ex to insert : f370a6aaaa87714bb13d219f79058549  ./DSC_2876.JPG
	echo -e "$1\t$2" >> "$nas_hashlist_with_filename"
}

remove_line_in_nashashlistwithfilename_from_path(){
	# ex : f370a6aaaa87714bb13d219f79058549  /path/to/DSC_2876.JPG
	sed -i '/$1/d' "$nas_hashlist_with_filename"
}
remove_line_in_nashashlistwithfilename_from_hash(){
	sed -i '/$1/d' "$nas_hashlist_with_filename"
}

update_nas_hashlist_based_on_nashashlistwithfilename(){
	# TODO 
	echo_verbose "-------------- Mise à jour des hashlists à partir de nas_hashlist_with_filename ------------------"

	echo_verbose "Mise à jour du nas_hashlist a partir du nas_hashlist_with_filename"
	cat "$nas_hashlist_with_filename" | awk '{print $1}' > "$nas_hashlist"

	echo_verbose "Mise à jour du nas_hashlist_uniq et nas_hashlist_duplciated"
	make_uniq_hashfile_folder
	if [ "$SOURCE_MODE" = "nas" ]; then
		make_duplicated_hashfile
	fi

	echo_verbose "Nettoyage des lignes vides dans les nas_hashfiles"
	sed -i '/^$/d' "$nas_hashlist_with_filename"
	sed -i '/^$/d' "$nas_hashlist"
	sed -i '/^$/d' "$nas_hashlist_uniq"
	sed -i '/^$/d' "$nas_hashlist_duplicated"

	echo_verbose "Triage des nas_hashlists"
	sort -o "$nas_hashlist_with_filename" "$nas_hashlist_with_filename"
	sort -o "$nas_hashlist" "$nas_hashlist"
}

show_and_move_location_already_copied_photos_on_nas(){
	echo_verbose "------------- Search files in hashlist that already exists in nas_hashlist -------------"
	comm -12 "$hashlist" "$nas_hashlist" > "$already_copied_photos_hashlist"
	extract_already_copied_location
}

extract_already_copied_location(){
	echo_verbose "------------- Already Copied files Locations -------------"
	echo_bold "## Photos déjà présentes ##" >> "$logfile"
	if [ -s "$already_copied_photos_hashlist" ]; then 
		while IFS="" read -r p || [ -n "$p" ]
		do
			already_copied_file=$(grep "$p" "$hashlist_with_filename" | awk -F"\t" '{print $2}'  | xargs -0)
			nas_file_location=$(grep "$p" "$nas_hashlist_with_filename" | awk -F"\t" '{print $2}'  | xargs -0)

			nas_parent_album=${nas_file_location#*/photo/*}
			nas_parent_album=`dirname "$nas_parent_album"`
			if [[ "$nas_file_location" == *"$nas_parent_album"* ]]; then
					# Dans le cas du déplacement d'un fichier depuis le NAS vers le NAS
					# on ignore
					echo_verbose "### Ignoring already found -- because file already on NAS ###"
					echo "nas_file_location=$nas_file_location"
					echo "nas_parent_album=$nas_parent_album"
					continue
			fi
			echo_verbose "##$nas_parent_album##  - ##$##"
			# TODO : gérer plusieurs retours ....
			echo_found "$already_copied_file : Trouvée - $nas_file_location" >> "$logfile"
			# TODO : pour vérifier la taille, le fichier sur le NAS est ... sur le nas ! donc comment connaitre sa taille ?
			# Option 1 : la création nas_hashlist donne la taille du fichier en 3ème colonne
			# Option 2 : le script move_tempphoto fait la comparaison car il est exécuté sur le NAS  --
					# Comparaison en locale : si même taille alors on va dire qu'il est forcément en double => INUTILE : car contourne ce qu'on veut faire via FOUND/ pour ne pas envoyer
			# => Option 1 pas le choix !
			# if [[ $(stat -c%s "$already_copied_file") -ne $(stat -c%s "$nas_file_location") ]];then
			# 		echo_verbose "Même hash mais pas la même taille des fichiers ... " >> "$logfile"
			# else
			# 		echo_verbose "Même hash et même taille de fichier -- semble vraiment identique." >> "$logfile"
			# fi
			((count_found++))
			mv "$already_copied_file" "$found_folder/"
			if [ "$SOURCE_MODE" = "nas" ]; then
				syno_reindex_needed=1
			fi
		done < "$already_copied_photos_hashlist"
		if [ $count_found -eq 0 ]; then
			echo_copied "Aucune photo déjà trouvée." >> "$logfile"
		fi
	fi
}


search_duplicated_files(){
	# Extract duplicated hashes
	echo_verbose "------------- Show missing files -------------"
	echo_bold "## Photos dupliquées ##" >> "$logfile"
	while IFS="" read -r duplicated_hash || [ -n "$duplicated_hash" ]
	do
		((count_duplicated++))
		count_total_local_photo_duplicated=0
		# 001d21360effa628a34c10e62fd2749e          /volume1/photo/Léon/2015/Février 2015/20150131-141311.JPG
		# 001d21360effa628a34c10e62fd2749e          /volume1/photo/Sauvegarde Caro/LEON/14mois/20150131-141311.JPG
	  	duplicated_photos=$(grep "$duplicated_hash" "$nas_hashlist_with_filename")
		echo "Photo (#$count_duplicated) : $duplicated_hash" >> "$logfile"
		while IFS="" read -r photo_hash_line || [ -n "$photo_hash_line" ]
		do
			((count_total_instance_duplicated++))
			((count_total_local_photo_duplicated++))
			photo=$(echo "$photo_hash_line" | awk -F"\t" '{print $2}' | xargs -0)
			echo "$count_total_local_photo_duplicated - $photo" >> "$logfile"
		done <<< "$duplicated_photos"
		echo "--------" >> "$logfile" 
		#((count_total_instance_duplicated+=$instance_duplicated))
	done < "$nas_hashlist_duplicated"
}

move_duplicated_files(){
	# Move files found elsewhere and move them into Duplicated folder
	echo_verbose "------------- Move duplicated files -------------"
	photos_in_album=$(grep "$remote_full_path_album" "$nas_hashlist_with_filename")
	# remote_full_path_album=/volume1/photo/Mariage Matt&Flo - 05-09-19/Eglise
	moved_photos=0
	if [ "$SOURCE_MODE" != "nas" ]; then
		echo_warning "read-only mode -- cannot move files !"
	fi
	while IFS="" read -r photo_hash_line || [ -n "$photo_hash_line" ]
	do
		photo_hash=$(echo "$photo_hash_line" | awk -F "\t" '{print $1}'  | xargs -0)
		photo_hash_path=$(echo "$photo_hash_line" | awk -F "\t" '{print $2}'  | xargs -0)
		if [ "$SOURCE_MODE" = "nas" ] && [ ! -f "$photo_hash_path" ]; then 
			echo_error "NAS hashfiles not uptodate.."
			echo_error "Source not exists : $photo_hash_path"
			continue
		fi
		if grep -q "$photo_hash" "$nas_hashlist_duplicated" ; then
			# move to DUPLICATED folder
			photos_duplicated=$(grep "$photo_hash" "$nas_hashlist_with_filename")
			while IFS="" read -r photo || [ -n "$photo" ]
			do
				photo_path=$(echo "$photo" | awk -F "\t" '{print $2}'  | xargs -0)
				photo_filename=`basename $photo_path` 
				to_move=$(echo "$photo_path" | grep -c "$remote_full_path_album")
				if [ "$to_move" -ne 0 ]; then
					if [ "$SOURCE_MODE" = "nas" ]; then
						# do mv
						if [ -f "$photo_path" ]; then 
							mv "$photo_path" "$duplicated_folder/"
							remove_line_in_nashashlistwithfilename_from_path "$photo_path"
							add_line_in_nashashlistwithfilename "$photo_hash" "$duplicated_folder/$photo_filename"
						else 
							echo_error "NAS hashfiles not uptodate.."
							echo_error "Duplicated file not exists : $photo_path"
						fi
						syno_reindex_needed=1
					else 
						echo "Simulate move from $photo_path to $duplicated_folder"
					fi
					((moved_photos++))
				fi
			done <<< $photos_duplicated
		fi
	done < "$photos_in_album"
	echo "Duplicated photo moved : $moved_photos"

	update_nas_hashlist_based_on_nashashlistwithfilename
}
clean_duplicated_files(){
	# Move files found elsewhere and move them into Duplicated folder
	echo_verbose "------------- Clean duplicated files -------------"
	photos_in_album=$(grep "$remote_full_path_album" "$nas_hashlist_with_filename")
	# remote_full_path_album=/volume1/photo/Mariage Matt&Flo - 05-09-19/Eglise
	moved_photos=0
	if [ "$SOURCE_MODE" != "nas" ]; then
		echo_warning "read-only mode -- cannot move files !"
	fi
	while IFS="" read -r photo_hash_line || [ -n "$photo_hash_line" ]
	do
		photo_hash=$(echo "$photo_hash_line" | awk -F "\t" '{print $1}'  | xargs -0)
		photo_hash_path=$(echo "$photo_hash_line" | awk -F "\t" '{print $2}'  | xargs -0)
		if [ "$SOURCE_MODE" = "nas" ] && [ ! -f "$photo_hash_path" ]; then 
			echo_error "NAS hashfiles not uptodate.."
			echo_error "Source not exists : $photo_hash_path"
			continue
		fi
		if grep -q "$photo_hash" "$nas_hashlist_duplicated" ; then
			# move to DUPLICATED folder
			photos_duplicated=$(grep "$photo_hash" "$nas_hashlist_with_filename")
			while IFS="" read -r photo || [ -n "$photo" ]
			do
				photo_path=$(echo "$photo" | awk -F "\t" '{print $2}'  | xargs -0)
				photo_filename=`basename $photo_path` 
				# must not match remote_full_path_album -- as we move only photo outside of this album
				to_move=$(echo "$photo_path" | grep -c "$remote_full_path_album")
				if [ "$to_move" -eq 0 ]; then
					if [ "$SOURCE_MODE" = "nas" ]; then
						# do mv
						if [ -f "$photo_path" ]; then 
							mv "$photo_path" "$duplicated_folder/"
							remove_line_in_nashashlistwithfilename_from_path "$photo_path"
							add_line_in_nashashlistwithfilename "$photo_hash" "$duplicated_folder/$photo_filename"
						else 
							echo_error "NAS hashfiles not uptodate.."
							echo_error "Duplicated file not exists : $photo_path"
						fi
						#echo "Simulate move from $photo_path to $duplicated_folder"
						#echo "Because : $photo_path exists here $photo_hash_path"
						syno_reindex_needed=1
					else 
						echo "Simulate move from $photo_path to $duplicated_folder"
						#echo "Because : $photo_path exists here $photo_hash_path"
					fi
					((moved_photos++))
				fi
			done <<< $photos_duplicated
		fi
	done < "$photos_in_album"
	echo "Duplicated photo moved : $moved_photos"
	#See if we remove those file from nas_hashfiles to make it more closer from real state

	update_nas_hashlist_based_on_nashashlistwithfilename
}

create_folder_or_keep_clean(){
	# TODO : verify if those files already exists before requesting to delete them
	folder="$1"
	if [ ! -d "$folder" ]; then
		mkdir "$folder"
	else
		if [ $(ls -1 "$folder" | wc -l) -ne 0 ]; then
			echo_warning "Fichier trouvés dans $folder..."
			ls -l "$folder"
			while true; do
				read -p "Veux tu nettoyer le dossier $folder?  [Oui/Non]" on
				case $on in
					[Oo]* )  rm "$folder"/*  ; break;;
					[Nn]* )  break;;
					* ) echo "Entrez Oui ou Non";;
				esac
			done
		fi
	fi
}

request_reindex_if_photos_moved(){

	if [ $BLOCK_REINDEX -eq 0 ]; then 
		reindexed=0
		previous_reindex_needed="0"
		if [ "$SOURCE_MODE" = "nas" ]; then 
			syno_reindex_need_file=/volume1/photo/syno_reindex_need_file
			previous_reindex_needed=$(cat $syno_reindex_need_file)

			if [ $syno_reindex_needed -eq 1 ] || [ "$previous_reindex_needed" = "1" ]; then
				
				
				# Request reindex
				while true; do
					read -p "Il faut réindexer le NAS, as tu terminé le rangement pour lancer la réindexation ?  [Oui/Non]" on
					case $on in
						[Oo]* )  echo_verbose "Reindéxation lancée : $path_to_script_folder/syno_reindex.sh" ; $current_dir/syno_reindex.sh ; reindexed=1; echo "0" > $syno_reindex_need_file ; break;;
						[Nn]* )  break;;
						* ) echo "Entrez Oui ou Non";;
					esac
				done

				if [ $reindexed -eq 0 ] && [ "$previous_reindex_needed" != "1" ]; then 
					# Stocker la réindexation
					echo_verbose "Saving reindexation into $syno_reindex_need_file"
					echo "1" > "$syno_reindex_need_file"
				fi
			fi
		fi	
	fi
}

clean_non_persistent_hashfiles(){
	if [ "$MODE" = copy ] || [ "$MODE" = test ]; then
		# Clean calculated hashes
		safe_remove "$hashlist_with_filename"
		safe_remove "$hashlist"
		safe_remove "$already_copied_photos_hashlist"
		safe_remove "$missing_hash_photos"
	fi
}

safe_remove(){
	if [[ "$1" == *"nas_hashlist"* ]]; then
		echo_error "SAFE-REMOVE : do not clean $1 because contains 'nas'"
	else 
		if [ ! -f "$1" ]; then 
			echo_error "SAFE-REMOVE : $1 not exists..."
		else 
			rm "$1"
		fi
	fi
}

############################### MAIN ###############################
start=`date +%s`
VERBOSE=0
SHORT=0
REUSE=0
BLOCK_REINDEX=0
force_logs=0
synology_host="synology"
syno_reindex_needed=0

if [[ "$HOSTNAME" == *"$synology_host"* ]]; then
	SOURCE_MODE="nas"
else
	SOURCE_MODE="pc"
fi

while [ $# -gt 0 ]; do
	case "$1" in
		-h|"-?"|--help)
			shift
			echo "usage: $0 [--block-reindex] [--clean_duplicated] [--copy source album_name] [--duplicate] [--log] [--move_duplicated] [--nas] [--reuse] [--short] [--test source album_name] [--verbose] "
			exit 0
			;;
		-b|--block-reindex)
			BLOCK_REINDEX=1
			shift;
			;;
		-c|--copy)
			MODE=copy
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
		-d|--duplicate)
			MODE=duplicate
			count_duplicated=0
			count_total_instance_duplicated=0
			shift;
			;;
		-l|--log)
			force_logs=1
			shift;
			;;
		--move_duplicated)
			MODE=move_duplicated
			if [ $# -lt 2 ]; then
				echo '1 paramètre est nécessaire : Nom de l album pour lequel les photos dupliquées seront mises de côté' 
				echo 'Example : check_fileexist_syno.sh --move_duplicated "Noël/Super Album - 25-12-19/"'
				exit -1
			else
				path_album_name=$2
				echo_verbose "Using path_album_name=$path_album_name"
			fi
			shift;
			shift;
			;;
		-n|--nas)
			check_syno_hostname
			MODE=nas
			shift;
			;;	
		--clean_duplicated)
			MODE=clean_duplicated
			if [ $# -lt 2 ]; then
				echo '1 paramètre est nécessaire : Nom de l album de référence pour lequel les photos qui existent ailleurs seront mises de côté' 
				echo 'Example : check_fileexist_syno.sh --clean_duplicated "Noël/Super Album - 25-12-19/"'
				exit -1
			else
				path_album_name=$2
				echo_verbose "Using path_album_name=$path_album_name"
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
		-v|--verbose)
			VERBOSE=1
			shift;
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
#path_to_script_folder="$prefix_path_syno_drive/tools/photos/merge_local_photos_into_nas"
path_to_script_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
path_to_remote_photo="/volume1/photo"

log_folder="$path_to_script_folder/script_logs/"
hashfile_location="$path_to_script_folder/hashfiles"
nas_hashlist="$hashfile_location/nas_hashlist.hash" #used for duplicated feature
nas_hashlist_with_filename="$hashfile_location/nas_hashlist_with_filename.hash"
nas_hashlist_uniq="$hashfile_location/nas_hashlist_uniq.hash"
nas_hashlist_duplicated="$hashfile_location/nas_hashlist_duplicated.hash"
if [ "$MODE" = move_duplicated ] || [ "$MODE" = clean_duplicated ]; then 
	remote_full_path_album="$path_to_remote_photo/$path_album_name"
	duplicated_folder="$remote_full_path_album/Duplicated"
	if [ "$SOURCE_MODE" = "nas" ]; then 
		create_folder_or_keep_clean "$duplicated_folder"
	fi 
fi
if [ "$MODE" = copy ] || [ "$MODE" = test ]; then
	## Checks
	if [ ! -d "$source_dcim_folder" ]; then
		echo_error "$source_dcim_folder folder not found!"
		exit -1
	else
		copied_folder="$source_dcim_folder/Copied"
		found_folder="$source_dcim_folder/Found"
		create_folder_or_keep_clean "$copied_folder"
		create_folder_or_keep_clean "$found_folder"
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
	already_copied_photos_hashlist="$hashfile_location/already_copied_photos_hashlist.hash"
	missing_hash_photos="$hashfile_location/missing_hash_photos.hash"
else if [ "$MODE" = nas ]; then
		source_dcim_folder="$path_to_remote_photo"
		hashlist_with_filename="$hashfile_location/nas_hashlist_with_filename.hash"
		hashlist="$hashfile_location/nas_hashlist.hash"
		hashlist_uniq="$hashfile_location/nas_hashlist_uniq.hash"
	fi
fi


today_date=`date +"%FT%H%M%S"`
logfile="$log_folder/$today_date-$MODE.log"
temp_new_hash_for_nas_hashlist="$log_folder/.tmp_nas_hashlist_$today_date.log"
count_copied=0
count_found=0
count_missing=0

echo_verbose "------------- Working on $HOSTNAME -------------"
prepare_logs

# If computer then compare and copy missings to new dest folder
if [ "$MODE" = duplicate ]; then
	search_duplicated_files
	echo "count_duplicated=$count_duplicated"
elif [ "$MODE" = move_duplicated ]; then 
	move_duplicated_files
	request_reindex_if_photos_moved
elif [ "$MODE" = clean_duplicated ]; then 
	clean_duplicated_files
	request_reindex_if_photos_moved
else 
	# Create hash_list for NAS or Computer
	echo_verbose "source_dcim_folder=$source_dcim_folder"
	make_hasfile_folder
	if [ "$MODE" = nas ]; then
		make_uniq_hashfile_folder
		make_duplicated_hashfile
	elif [ "$MODE" = copy ] || [ "$MODE" = test ]; then
		prepare_destination_folder
		search_missing_photos
		if [ "$MODE" = copy ]; then
			copy_missing_filenames
			show_and_move_location_already_copied_photos_on_nas
			request_reindex_if_photos_moved
		elif [ "$MODE" = test ]; then
			show_and_move_location_already_copied_photos_on_nas
		else 
			echo_error "Mode=$MODE unrecognized"
			exit -2
		fi
		clean_non_persistent_hashfiles
	fi
fi

# Clean old logs 
find "$log_folder" -type f -name "*$MODE.log" -ctime +15 -print #-delete

end=`date +%s`
runtime=$((end-start))
displaytime $runtime

show_logs