# Script to be un on NAS only !
# Features
## Move temp_photo to photo (when sure they are arrived)
## Update the album_photo_rights_to_be_reviewed AND notify

xxh_location=/volume1/tools/photos/xxHash-0.7.3/xxhsum
date=`date`
album_photo_rights_to_be_reviewed=/volume1/photo/album_photo_rights_to_be_reviewed.txt
error=0
permission_added=0
proceed=0
block_reindex=0

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
reindex_script=$current_dir/test_check_fileexist.sh

echo_success(){
  echo -e "\e[32m$1\e[0m"
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

echo "Exécution du : $date"
## Loop over all folders in /temp_photo to move each of them
for d in /volume1/temp_photos/*/ ; do
    ## For each :
    if [ "$d" == "/volume1/temp_photos/@eaDir/" ]; then
      continue
    fi

    file_not_ready=0
    ### Identify final folder
    copied_hash_found=`find "$d" -type f -name copied_hashlist.hash`
    #echo "copied_hash_found=$copied_hash_found"
    while IFS= read -r album_copied_hashlist
  	do
      echo "album_copied_hashlist=$album_copied_hashlist"
      if [ ! -z "$album_copied_hashlist" ] || [ "$album_copied_hashlist" = "." ]; then

        ### Identify copied_hashlist
        dir=`dirname "$album_copied_hashlist"` #dir=/volume1/temp_photos/Noël/Super Album - 25-12-19
        album_name=`basename "$dir"` #album_name=Super Album - 25-12-19
        path_album_name=${dir//"/volume1/temp_photos/"/} #path_album_name=Noël/Super Album - 25-12-19
        # If file not ready then cannot proccess this folder
        if [ ! -f "$album_copied_hashlist" ]; then
            echo_warning "Album $path_album_name pas prêt."
        else

          echo "-----"
          echo_bold "Album : $path_album_name"
          ### - Open copied_hashlist to identify photo that must have been sync (or wait if not ready)
          ### Count number of photo that must be found
          sed -i '/^$/d' "$album_copied_hashlist"  # WARNING : potentielles lignes vides à retirer
          count_photos_in_copied_hashlist=`wc -l "$album_copied_hashlist" | awk '{ print $1 }'`
          # echo "count_photos_in_copied_hashlist = $count_photos_in_copied_hashlist"
          #### If there is the same number in the folder (and in the file) so continue
          count_photos_local=`ls -1q "$dir" | wc -l | awk '{ print $1 }'`
          # WARNING : 1 ligne pour copied_hashlist.hash !
          ((count_photos_local--))
          # echo "count_photos_local = $count_photos_local"
          if [ $count_photos_in_copied_hashlist -ne $count_photos_local ];then
              echo "Prévues : $count_photos_in_copied_hashlist -- Trouvées : $count_photos_local"
          fi
            ### xxh all photo (basename de awk $2) to make sure they are ready to be moved
            while IFS="" read -r p || [ -n "$p" ]
            do
              # 3c079ec2b7095f3f05c786ad89edc14c        /volume1/photo/Mon album 1/photo3.png
              local_file_fullpath=`echo "$p" | awk -F"\t" '{print $2}' | xargs`
              original_hash=`echo "$p" | awk '{print $1}'`
              local_file=`basename "$local_file_fullpath"`
              # file_to_hash : ""/volume1/photo/Mon album 1/photo3.png"
              hash_file=`$xxh_location -H2 "$dir/$local_file" | awk '{ print $1 }'`
              # hash_file : 3c079ec2b7095f3f05c786ad89edc14c

              if [ "$hash_file" != "$original_hash" ]; then
                  # One of the file not ready
                  # wait
                  file_not_ready=1
                  break
              fi

              if [ $file_not_ready -eq 1 ]; then
                  # Keep this folder for later
                  break
              fi
              ### At this stage, all photos are ready to be moved
              #### identify if folder already exists -->
              dest_folder_album_path=`dirname "$local_file_fullpath"`
              if [ ! -d "$dest_folder_album_path" ]; then
                  #### if not then create a new one and then append to album_photo_rights_to_be_reviewed.txt
                  mkdir -p "$dest_folder_album_path"
                  echo -e "## $date\n$dest_folder_album_path" >> $album_photo_rights_to_be_reviewed
                  permission_added=1
              fi
              ### Move the files
              # echo "Déplacement de : $local_file"
              mv "$dir/$local_file" "$local_file_fullpath"
              proceed=1

            done < $album_copied_hashlist
            echo_success "Toutes les photos déplacées"
            remaining_files=`ls -A "$dir"`
            if [ "$remaining_files" == "copied_hashlist.hash" ]; then
                # clean copied_hashlist
                rm "$dir/copied_hashlist.hash"

                # echo "Removing folder : $d"
                rm -d "$dir"
            fi
        fi
      fi
  	done <<< $copied_hash_found
done

# Clean all empty folders under /volume1/temp_photos
for dir in /volume1/temp_photos/*/ ; do
  if [ "$dir" == "/volume1/temp_photos/@eaDir/" ]; then
    continue
  fi
  find "$dir" -type d -empty -delete
done

if [ $error -eq 1 ]; then
  echo_error "Merci de corriger."
  exit -1
fi

if [ $permission_added -eq 1 ]; then
    echo -e "\n----------- Permissions à donner -----------"
    echo "-- Fichier des permissions : $album_photo_rights_to_be_reviewed"
    cat $album_photo_rights_to_be_reviewed
    exit 2
fi

# Force syno to reindex if proceed 
syno_reindex_need_file=/volume1/photo/syno_reindex_need_file
previous_reindex_needed=$(cat $syno_reindex_need_file)
if [ $proceed -eq 1 ]; then 
  if [ $block_reindex -eq 0 ];then 
    if [ -f "$reindex_script" ]; then 
      echo "Reindexation started"
      $reindex_script
      if  [ "$previous_reindex_needed" != "0" ]; then
        echo "Reseting reindexation"
        echo "0" > $syno_reindex_need_file
      fi 
    else 
      echo_error "Reindex script not found !"
      exit -1
    fi
  else 
    if  [ "$previous_reindex_needed" != "1" ]; then
      echo "Saving reindexation needed"
      echo "1" > $syno_reindex_need_file
    fi
  fi
fi
