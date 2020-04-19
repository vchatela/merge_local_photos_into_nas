sudo mkdir -p /mnt/h
sudo mount -t drvfs H: /mnt/h
/mnt/d/Syno/tools/photos/check_fileexist_syno.sh --$1 /mnt/h/DCIM/100D5300/ "$2"
