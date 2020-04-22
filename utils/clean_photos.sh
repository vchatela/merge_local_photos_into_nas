mv /tmp/test_copy_photos/Copied/* /tmp/test_copy_photos/ 2> /dev/null
if [[ "$HOSTNAME" == *"synology"* ]]; then
		prefix_path_syno_drive="/volume1/"
else
		prefix_path_syno_drive="/mnt/d/Syno/"
fi
hashfile_location="$prefix_path_syno_drive/tools/photos/merge_local_photos_into_nas/hashfiles"
nas_hashlist="$hashfile_location/nas_hashlist.hash"
nas_hashlist_with_filename="$hashfile_location/nas_hashlist_with_filename.hash"

sed -i '/^3c079ec2b7095f3f05c786ad89edc14c/d' $nas_hashlist
sed -i '/^3c079ec2b7095f3f05c786ad89edc14c/d' $nas_hashlist_with_filename
sed -i '/^62f599af1fc5ed02f4a0ba23076c0d9e/d' $nas_hashlist
sed -i '/^62f599af1fc5ed02f4a0ba23076c0d9e/d' $nas_hashlist_with_filename
sed -i '/^a4c3374cb47c8ccb88032a7db564330f/d' $nas_hashlist
sed -i '/^a4c3374cb47c8ccb88032a7db564330f/d' $nas_hashlist_with_filename

# Versison 7.3 xxh
sed -i '/^12b9ef0f6f899ba279911d838a5daa3e/d' $nas_hashlist
sed -i '/^12b9ef0f6f899ba279911d838a5daa3e/d' $nas_hashlist_with_filename
sed -i '/^aa7b076cbac4bceb352cfa3d084be34f/d' $nas_hashlist
sed -i '/^aa7b076cbac4bceb352cfa3d084be34f/d' $nas_hashlist_with_filename
sed -i '/^a09a7a222b94bbdf5618a18dda32e66c/d' $nas_hashlist
sed -i '/^a09a7a222b94bbdf5618a18dda32e66c/d' $nas_hashlist_with_filename

sed -i '/^$/d' $nas_hashlist
sed -i '/^$/d' $nas_hashlist_with_filename
