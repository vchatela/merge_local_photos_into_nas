if [ "$EUID" -ne 0 ]
	then echo "Please run as root"
  exit
fi

## relance l'indexation
synoservicecfg --enable synoindexd
## relance la création des miniatures
synoservicecfg --enable synomkthumbd
##relance la conversion photo/video
synoservicecfg --enable synomkflvd