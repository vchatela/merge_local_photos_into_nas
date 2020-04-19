#/bin/bash
#exiftool -a -F -r -i @eaDir -d %Y%m%d-%H%M%S%%-c.%%e "-testname<CreateDate" $folder
#folder="/volume1/photo/La Rochelle - 26-04-16/"
logfile=/volume1/logs/tools/exiftool_rundate.txt
echo -n `date +"[%m-%d %H:%M:%S]"` >> $logfile


if [ $# -eq 1 ] && [ -d "$1" ]; then
	folder="$1"
else
	#folder="/volume1/photo/Noël/"
	folder="/volume1/photo/"
fi

echo > /volume1/logs/tools/exiftool.err
echo -e "Folder=$folder\n" | tee $logfile

## Rename
exiftool -a -q -q -F -r -m -i @eaDir -i "#recycle" -d %Y%m%d-%H%M%S%%-c.%%e "-filename<CreateDate" "$folder" 2> /volume1/logs/tools/exiftool.err
result=$?
if [ ! $result -eq 0 ]; then
	>&2 date ; cat /volume1/logs/tools/exiftool.err
	exit $?
fi

## relance l'indexation
sudo synoservicecfg --enable synoindexd
## relance la création des miniatures
sudo synoservicecfg --enable synomkthumbd
##relance la conversion photo/video
sudo synoservicecfg --enable synomkflvd