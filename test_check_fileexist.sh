# find /mnt/d/Syno/tools/photos/sources_test -type f -type f -not -path '*@eaDir*' ! -name 'SYNO@.fileindexdb' ! -name 'Thumbs.db' ! -name '*.sort' \( -name "*.png" -or -name "*.PNG" -or -name "*.jpeg" -or -name "*.jpg" -or -name "*.JPG" \) -exec /mnt/d/xxHash-0.7.2/xxh64sum -H2 "{}" + | sort | sed -r -e 's/^[a-zA-Z0-9]{32}/&\t/'
#	3c079ec2b7095f3f05c786ad89edc14c          /mnt/d/Syno/tools/photos/sources_test/photo3.png
#	62f599af1fc5ed02f4a0ba23076c0d9e          /mnt/d/Syno/tools/photos/sources_test/photo1.png
#	a4c3374cb47c8ccb88032a7db564330f          /mnt/d/Syno/tools/photos/sources_test/photo2.png

# Version xxHash-0.7.2
# xxh_hash_photo1="62f599af1fc5ed02f4a0ba23076c0d9e"
# xxh_hash_photo2="a4c3374cb47c8ccb88032a7db564330f"
# xxh_hash_photo3="3c079ec2b7095f3f05c786ad89edc14c"

# Version xxHash-0.7.3
xxh_hash_photo1="12b9ef0f6f899ba279911d838a5daa3e"
xxh_hash_photo2="aa7b076cbac4bceb352cfa3d084be34f"
xxh_hash_photo3="a09a7a222b94bbdf5618a18dda32e66c"


synology_host="synology"

if [[ "$HOSTNAME" == *"$synology_host"* ]]; then
	path_to_sources_test="/volume1/tools/photos/merge_local_photos_into_nas/sources_test"
else
	path_to_sources_test="/mnt/d/Syno/tools/photos/merge_local_photos_into_nas/sources_test"
fi



add_photo_to_knowledge_nashashlists(){
	if [ "$1" == "photo1" ]; then
		echo_verbose "Adding Photo 1 to $nas_hashlist_with_filename and $nas_hashlist"
		echo -e "$xxh_hash_photo1 \t $local_final_dest_folder/$photo1" >> $nas_hashlist_with_filename
		echo "$xxh_hash_photo1" >> $nas_hashlist
	elif [ "$1" == "photo2" ]; then
		echo_verbose "Adding Photo 2 to $nas_hashlist_with_filename and $nas_hashlist"
		echo -e "$xxh_hash_photo2 \t $local_final_dest_folder/$photo2" >> $nas_hashlist_with_filename
		echo "$xxh_hash_photo2" >> $nas_hashlist
	elif [ "$1" == "photo3" ]; then
		echo_verbose "Adding Photo 3 to $nas_hashlist_with_filename and $nas_hashlist"
	 echo -e "$xxh_hash_photo3 \t $local_final_dest_folder/$photo3" >> $nas_hashlist_with_filename
 	 echo "$xxh_hash_photo3" >> $nas_hashlist
 else
	 echo "ERROR : $1 not a known photo"
	 exit -2
	fi

	echo_verbose "Sorting $nas_hashlist_with_filename and $nas_hashlist"
	sort -o $nas_hashlist_with_filename $nas_hashlist_with_filename
	sort -o $nas_hashlist $nas_hashlist
}

test_pc(){
	verify test1
	verify test2
	verify test3
}

test_syno(){
	verify test5
	verify test6
	verify test7
	#verify test8
	verify test9
	verify test10
}

verify(){
	if "$1" ; then
			echo_success "$1 success"
	else
			echo_error "$1 failed"
	fi
}

echo_error(){
  echo -e "\e[91m----------- ERREUR -----------\n$1\e[0m"
}

echo_success(){
  echo -e "\e[32m$1\e[0m"
}

check_pc_hostname(){
	if [[ "$HOSTNAME" == *"$synology_host"* ]]; then
		echo "ERROR : not on PC -- detected on synology.."
		exit -2
	fi
}

check_syno_hostname(){
	echo "$HOSTNAME"
	if [[ "$HOSTNAME" != *"$synology_host"* ]]; then
		echo "ERROR : not on synology.."
		exit -2
	fi
}


# Copie de 2 nouvelles photos sans colisions
test1(){
	echo "## Test 1 ##"
	check_pc_hostname
	# Préparer le dossier
	test_folder="/tmp/test_copy_photos/"
	path_album_name="Test - 01-01-01"
	local_final_dest_folder="/mnt/d/Syno/temp_photos/$path_album_name"
	mkdir -p "$test_folder"

	expected_added_lines_nas_hashlist="$test_folder/expected_added_lines_nas_hashlist.txt"
	echo "" > $expected_added_lines_nas_hashlist

	photo1=photo1.png
	photo2=photo2.png

	cp "$path_to_sources_test/$photo1" "$test_folder"
	cp "$path_to_sources_test/$photo2" "$test_folder"

	# Lancer le script
	error=0
	echo "## Run script ##"
	$check_fileexist_syno --copy "$test_folder" "$path_album_name" --log --block-reindex

	# Vérifie que les photos sont présentes dans le dossier temp_photos
	verify_tempphoto photo1 photo2
	# Force crontab pour déplacer au final
	# TODO

	# Vérifier la maj du nas_hashlist
	verify_nas_hashlist photo1 photo2

	echo "Result : $error"
	# Cleanup
	cleanup
	return $error
}

# Copie de 2 nouvelles photos + 1 colision
test2(){
	echo "## Test 2 ##"
	check_pc_hostname
	# Préparer le dossier
	test_folder="/tmp/test_copy_photos/"
	path_album_name="Test - 01-01-01"
	local_final_dest_folder="/mnt/d/Syno/temp_photos/$path_album_name"
	mkdir -p "$test_folder"

	photo1=photo1.png
	photo2=photo2.png
	photo3=photo3.png

	cp "$path_to_sources_test/$photo1" $test_folder
	cp "$path_to_sources_test/$photo2" $test_folder
	cp "$path_to_sources_test/$photo3" $test_folder

	# Forcer que photo3.png existe dans le référentiel même si non présente
	add_photo_to_knowledge_nashashlists "photo3"

	# Lancer le script
	error=0
	echo "## Run script ##"
	$check_fileexist_syno --copy "$test_folder" "$path_album_name" --log --block-reindex

	# Vérifie que les photos sont présentes dans le dossier temp_photos
	if [ ! -f "$local_final_dest_folder/$photo1" ]; then
		echo "ERRREUR photo1 non trouvée ici : $local_final_dest_folder/$photo1"
		error=1
	fi
	if [ ! -f "$local_final_dest_folder/$photo2" ]; then
		echo "ERRREUR photo2 non trouvée ici : $local_final_dest_folder/$photo2"
		error=1
	fi
	if [ -f "$local_final_dest_folder/$photo3" ]; then
		echo "ERRREUR photo trouvée ici alors que déjà présente : $local_final_dest_folder/$photo3 .. -> Vérification dans nas_hashlist_with_filename:$nas_hashlist_with_filename :"
		grep "$xxh_hash_photo3" $nas_hashlist_with_filename
		error=1
	fi

	# Force crontab pour déplacer au final
	# TODO

	# Vérifie que les photos sont présentes dans le dossier final
	verify_tempphoto photo1 photo2

	# Vérifier la maj du nas_hashlist
	verify_nas_hashlist photo1 photo2

	echo "Result : $error"

	# Cleanup
	cleanup
	return $error
}

# Validation du fichier
test3(){
	echo "## Test 3 ##"
	check_pc_hostname
	# Préparer le dossier
	test_folder="/tmp/test_copy_photos/"
	path_album_name="Test - 01-01-01"
	local_final_dest_folder="/mnt/d/Syno/temp_photos/$path_album_name"
	copied_hashlist="$local_final_dest_folder/copied_hashlist.hash"
	mkdir -p "$test_folder"

	expected_added_lines_nas_hashlist="$test_folder/expected_added_lines_nas_hashlist.txt"
	echo "" > $expected_added_lines_nas_hashlist

	photo1=photo1.png
	photo2=photo2.png

	cp "$path_to_sources_test/$photo1" "$test_folder"
	cp "$path_to_sources_test/$photo2" "$test_folder"

	# Lancer le script
	error=0
	echo "## Run script ##"
	$check_fileexist_syno --copy "$test_folder" "$path_album_name" --log --block-reindex

	# Vérifie que les photos sont présentes dans le dossier temp_photos
	verify_tempphoto photo1 photo2
	# Verification du copied_hashlist
	verify_copied_hashlist photo1 photo2

	echo "Result : $error"
	# Cleanup
	cleanup
	return $error
}

# TODO !
# Validation de la fonction --test
test4(){
	error=0
	# On lance le test et on vérifie qu'il n'y a aucune modifications

	# Cleanup
	cleanup
	return $error
}

#simulate on NAS
test5(){
	echo "## Test 5 ##"
	check_syno_hostname
# Backup old hashlists
	backup_nas_hashlists

	error=0
	echo "## Run script ##"
	$check_fileexist_syno --verbose --log --nas --short 50 ## --block-reindex     NOT needed because no move
	# Verifications
	echo "##### hashlist_with_filename contenu #####"
	echo "show only 10"
	cat $nas_hashlist_with_filename | head -10
	echo "##### Hashlist contenu #####"
	echo "show only 10"
	cat $nas_hashlist | head -10

# Restore hashlists
	restore_nas_hashlists
	return $error
}

# Copy sur NAS
test6(){
	echo "## Test 6 ##"
	check_syno_hostname
	# Préparer le dossier
	test_folder="/tmp/test_copy_photos/"
	path_album_name="Test - 01-01-01"
	local_final_dest_folder="/volume1/temp_photos/$path_album_name"
	copied_hashlist="$local_final_dest_folder/copied_hashlist.hash"
	mkdir -p "$test_folder"

	expected_added_lines_nas_hashlist="$test_folder/expected_added_lines_nas_hashlist.txt"
	echo "" > $expected_added_lines_nas_hashlist

	photo1=photo1.png
	photo2=photo2.png

	cp "$path_to_sources_test/$photo1" "$test_folder"
	cp "$path_to_sources_test/$photo2" "$test_folder"

	# Lancer le script
	error=0
	echo "## Run script ##"
	$check_fileexist_syno --verbose --copy "$test_folder" "$path_album_name" --log --block-reindex
	# Verifications
	# Vérifie que les photos sont présentes dans le dossier temp_photos
	verify_tempphoto photo1 photo2
	# Vérifier la maj du nas_hashlist
	verify_nas_hashlist photo1 photo2

	echo "Result : $error"
	# Cleanup
	cleanup
	return $error
}

# Validation de la copie avec sous dossier
test7(){
	echo "## Test 7 ##"
	check_syno_hostname
	# Préparer le dossier
	test_folder="/tmp/test_copy_photos/"
	path_album_name="Test/Test - 01-01-01"
	local_final_dest_folder="/volume1/temp_photos/$path_album_name"
	copied_hashlist="$local_final_dest_folder/copied_hashlist.hash"
	mkdir -p "$test_folder"

	expected_added_lines_nas_hashlist="$test_folder/expected_added_lines_nas_hashlist.txt"
	echo "" > $expected_added_lines_nas_hashlist

	photo1=photo1.png
	photo2=photo2.png

	cp "$path_to_sources_test/$photo1" "$test_folder"
	cp "$path_to_sources_test/$photo2" "$test_folder"

	# Lancer le script
	error=0
	echo "## Run script ##"
	$check_fileexist_syno --verbose --copy "$test_folder" "$path_album_name" --log --block-reindex
	# Verifications
	# Vérifie que les photos sont présentes dans le dossier temp_photos
	verify_tempphoto photo1 photo2
	# Vérifier la maj du nas_hashlist
	verify_nas_hashlist photo1 photo2

	echo "Result : $error"
	# Cleanup
	cleanup
	return $error
}

# Validation du reuse
#test8(){
#	echo "## Test 8 ##"
#	check_syno_hostname
#	error=0
#	echo "## Run script ##"
#	$check_fileexist_syno --verbose --reuse --copy "$test_folder" --log

#	return $error
#}

# Fonction sur le NAS pour tester move_tempphoto_to_photo
test9(){
	echo "## Test 9 ##"
	check_syno_hostname
	# Préparer le dossier
	test_folder="/tmp/test_copy_photos/"
	path_album_name="Test - 01-01-01"
	local_final_dest_folder="/volume1/temp_photos/$path_album_name"
	copied_hashlist="$local_final_dest_folder/copied_hashlist.hash"
	mkdir -p "$test_folder"

	expected_added_lines_nas_hashlist="$test_folder/expected_added_lines_nas_hashlist.txt"
	echo "" > $expected_added_lines_nas_hashlist

	photo1=photo1.png
	photo2=photo2.png

	cp "$path_to_sources_test/$photo1" "$test_folder"
	cp "$path_to_sources_test/$photo2" "$test_folder"

	# Lancer le script
	error=0
	echo "## Run check_fileexist_syno : $check_fileexist_syno ##"
	$check_fileexist_syno --verbose --copy "$test_folder" "$path_album_name" --log --block-reindex

	echo "## Run move_tempphoto_to_photo : $move_tempphoto_to_photo ##"
	$move_tempphoto_to_photo
	# Verifications
	# Vérifie que les photos sont présentes dans le dossier photos
	verify_photo photo1 photo2

	echo "Result : $error"
	# Cleanup
	cleanup
	return $error
}

# Fonction sur le NAS pour tester move_tempphoto_to_photo avec sous dossier
test10(){
	echo "## Test 10 ##"
	check_syno_hostname
	# Préparer le dossier
	test_folder="/tmp/test_copy_photos/"
	path_album_name="Test/Test - 01-01-01"
	local_final_dest_folder="/volume1/temp_photos/$path_album_name"
	copied_hashlist="$local_final_dest_folder/copied_hashlist.hash"
	mkdir -p "$test_folder"

	expected_added_lines_nas_hashlist="$test_folder/expected_added_lines_nas_hashlist.txt"
	echo "" > $expected_added_lines_nas_hashlist

	photo1=photo1.png
	photo2=photo2.png

	cp "$path_to_sources_test/$photo1" "$test_folder"
	cp "$path_to_sources_test/$photo2" "$test_folder"

	# Lancer le script
	error=0
	echo "## Run check_fileexist_syno : $check_fileexist_syno ##"
	$check_fileexist_syno --verbose --copy "$test_folder" "$path_album_name" --log --block-reindex

	echo "## Run move_tempphoto_to_photo : $move_tempphoto_to_photo ##"
	$move_tempphoto_to_photo
	# Verifications
	# Vérifie que les photos sont présentes dans le dossier photos
	verify_photo photo1 photo2

	echo "Result : $error"
	# Cleanup
	cleanup
	return $error
}

# backup old hashlists
backup_nas_hashlists(){
	echo "### Backup haslists nas ###"
	cp $nas_hashlist_with_filename $nas_hashlist_with_filename.$today_date
	cp $nas_hashlist $nas_hashlist.$today_date
	cp $nas_hashlist_uniq $nas_hashlist_uniq.$today_date
}

backup_hashlists(){
	echo "### Backup haslists ###"
	cp $hashlist_with_filename $hashlist_with_filename.$today_date
	cp $hashlist $hashlist.$today_date
	cp $hashlist_uniq $hashlist_uniq.$today_date
}

# restore old hashlists
restore_hashlists(){
	echo "### Restoring haslists ###"
	echo "# Delete temp #"
	rm $hashlist_with_filename
	rm $hashlist
	rm $hashlist_uniq

	echo "# Restoring olds #"
	mv $hashlist_with_filename.$today_date $hashlist_with_filename
	mv $hashlist.$today_date $hashlist
	mv $hashlist_uniq.$today_date $hashlist_uniq
}

restore_nas_hashlists(){
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

# Nettoyage du test
cleanup(){
	echo "## Cleanup ##"
	## 1. Nettoyage dossiers test_folder et local_final_dest_folder
	rm -rf "$local_final_dest_folder"

	if [ $clean_all -eq 1 ]; then
		rm -rf $test_folder/*
	else
		rm -f $test_folder/photo*.png
	fi

	## 2. Nettoyer les lignes dans NAS
	# 3c079ec2b7095f3f05c786ad89edc14c  /mnt/d/Syno/tools/photos/sources_test/photo3.png
	# 62f599af1fc5ed02f4a0ba23076c0d9e  /mnt/d/Syno/tools/photos/sources_test/photo1.png
	# a4c3374cb47c8ccb88032a7db564330f  /mnt/d/Syno/tools/photos/sources_test/photo2.png
	echo_verbose "Removing hashes of known nas_hashlists"

	sed -i "/^$xxh_hash_photo3/d" $nas_hashlist
	sed -i "/^$xxh_hash_photo3/d" $nas_hashlist_with_filename

	sed -i "/^$xxh_hash_photo1/d" $nas_hashlist
	sed -i "/^$xxh_hash_photo1/d" $nas_hashlist_with_filename

	sed -i "/^$xxh_hash_photo2/d" $nas_hashlist
	sed -i "/^$xxh_hash_photo2/d" $nas_hashlist_with_filename
	found=`grep -c "$xxh_hash_photo3" $nas_hashlist_with_filename || grep "$xxh_hash_photo1" $nas_hashlist_with_filename || grep "$xxh_hash_photo2" $nas_hashlist_with_filename`
	if [ $found -ne 0 ]; then
		echo "ERROR : Hashes found in nas_hashlist_with_filename .."
		grep "$xxh_hash_photo3" $nas_hashlist_with_filename
		grep "$xxh_hash_photo1" $nas_hashlist_with_filename
		grep "$xxh_hash_photo2" $nas_hashlist_with_filename
	fi
}

verify_file_hashlist(){
	# $1 : file to check in
	# it can be : nas_hashlist or copied_hashlist
	# structure must be : hash    path
	error=0
  hashfile="$1"
	shift
	for photo in "$@"
	do
		if [ "$photo" == photo1 ]; then
				found_photo1=`grep "$xxh_hash_photo1" "$hashfile" | grep -c "/volume1/photo/$path_album_name/photo1.png" "$hashfile"`
				if [ $found_photo1 -eq 0 ]; then
					error=1
					echo "ERROR on $photo"
					grep "$xxh_hash_photo1" "$hashfile"
				fi
		elif [ "$photo" == photo2 ]; then
				found_photo2=`grep "$xxh_hash_photo2" "$hashfile" | grep -c "/volume1/photo/$path_album_name/photo2.png" "$hashfile"`
				if [ $found_photo2 -eq 0 ]; then
					error=1
					echo "ERROR on $photo"
					grep "$xxh_hash_photo2" "$hashfile"
				fi
		#elif  [ "$photo" == photo3 ]; then
		else
				echo "ERROR : photo not known...."
		fi
	done
}

verify_copied_hashlist(){
	echo "### Verify Copied Hashlist ###"
	echo "Copied Hashlist : $copied_hashlist"
	verify_file_hashlist "$copied_hashlist" photo1 photo2
}

verify_nas_hashlist(){
	echo "### Verify NAS Hashlist ###"
	verify_file_hashlist "$nas_hashlist_with_filename" photo1 photo2
}

verify_tempphoto(){
	error=0
	for photo in "$@"
	do
		if [ "$photo" == photo1 ]; then
			if [ ! -f "$local_final_dest_folder/$photo1" ]; then
				echo "ERRREUR photo1 non trouvée ici : $local_final_dest_folder/$photo1"
				if [ ! -d "$local_final_dest_folder" ]; then
					echo "ERRREUR dossier dest n'existe pas : $local_final_dest_folder"
				else
					ls -la "$local_final_dest_folder"
				fi
				error=1
			fi
		elif [ "$photo" == photo2 ]; then
			if [ ! -f "$local_final_dest_folder/$photo2" ]; then
				echo "ERRREUR photo2 non trouvée ici : $local_final_dest_folder/$photo2"
				if [ ! -d "$local_final_dest_folder" ]; then
					echo "ERRREUR dossier dest n'existe pas : $local_final_dest_folder"
				else
					ls -la "$local_final_dest_folder"
				fi
				error=1
			fi
		#elif  [ "$photo" == photo3 ]; then
		else
				echo "ERROR : photo not known...."
		fi
	done
}

verify_photo(){
	error=0
	for photo in "$@"
	do
		if [ "$photo" == photo1 ]; then
			if [ ! -f "/volume1/photo/$path_album_name/$photo1" ]; then
				echo "ERRREUR photo1 non trouvée ici : /volume1/photo/$path_album_name/$photo1"
				if [ ! -d "/volume1/photo/$path_album_name" ]; then
					echo "ERRREUR dossier dest n'existe pas : /volume1/photo/$path_album_name"
				else
					ls -la "/volume1/photo/$path_album_name"
				fi
				error=1
			fi
		elif [ "$photo" == photo2 ]; then
			if [ ! -f "/volume1/photo/$path_album_name/$photo2" ]; then
				echo "ERRREUR photo2 non trouvée ici : /volume1/photo/$path_album_name/$photo2"
				if [ ! -d "/volume1/photo/$path_album_name" ]; then
					echo "ERRREUR dossier dest n'existe pas : /volume1/photo/$path_album_name"
				else
					ls -la "/volume1/photo/$path_album_name"
				fi
				error=1
			fi
		#elif  [ "$photo" == photo3 ]; then
		else
				echo "ERROR : photo not known...."
		fi
	done
}

echo_verbose(){
	if [ $VERBOSE -eq 1 ]; then
		echo $1
	fi
}

VERBOSE=0
clean_all=1
today_date=`date +"%FT%H%M%S"`

if [[ "$HOSTNAME" == *"$synology_host"* ]]; then
		prefix_path_syno_drive="/volume1/"
else
		prefix_path_syno_drive="/mnt/d/Syno/"
fi
path_to_script_folder="$prefix_path_syno_drive/tools/photos/merge_local_photos_into_nas"
hashfile_location="$path_to_script_folder/hashfiles"
check_fileexist_syno="$path_to_script_folder/check_fileexist_syno.sh"
move_tempphoto_to_photo="$path_to_script_folder/move_tempphoto_to_photo.sh"

if [[ "$HOSTNAME" == *"$synology_host"* ]]; then
	path_to_remote_photo="/volume1/photo"
	source_dcim_folder="$path_to_remote_photo"
	nas_hashlist_with_filename="$hashfile_location/nas_hashlist_with_filename.hash"
	nas_hashlist="$hashfile_location/nas_hashlist.hash"
	nas_hashlist_uniq="$hashfile_location/nas_hashlist_uniq.hash"
else
	hashlist_with_filename="$hashfile_location/dcim_hashlist_with_filename.hash"
	hashlist="$hashfile_location/dcim_hashlist.hash"
	nas_hashlist="$hashfile_location/nas_hashlist.hash"
	nas_hashlist_with_filename="$hashfile_location/nas_hashlist_with_filename.hash"
fi


for test in "$@"
do
	verify $test
done
