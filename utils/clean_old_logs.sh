if [[ "$HOSTNAME" == *"synology"* ]]; then
		prefix_path_syno_drive="/volume1/"
else
		prefix_path_syno_drive="/mnt/d/Syno/"
fi
log_folder="$prefix_path_syno_drive/tools/photos/merge_local_photos_into_nas/script_logs/"
#echo "Cleaning of $log_folder"

if [[ "$log_folder" ==  *"/tools/photos/merge_local_photos_into_nas/script_logs/"* ]]; then
  find $log_folder -mindepth 1 -ctime +30 -delete
else
  echo "Error : path to log_folder in error : $log_folder"
fi
