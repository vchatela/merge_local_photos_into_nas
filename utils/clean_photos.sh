mv /tmp/test_copy_photos/Copied/* /tmp/test_copy_photos/
path_to_root_script_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && cd .. && pwd )"
path_to_remote_photo="/volume1/photo"
hashfile_location="$path_to_root_script_folder/hashfiles"
nas_hashlist="$hashfile_location/nas_hashlist.hash"
nas_hashlist_with_filename="$hashfile_location/nas_hashlist_with_filename.hash"
nas_hashlist_uniq="$hashfile_location/nas_hashlist_uniq.hash"
nas_hashlist_duplicated="$hashfile_location/nas_hashlist_duplicated.hash"

sed -i '/^3c079ec2b7095f3f05c786ad89edc14c/d' "$nas_hashlist"
sed -i '/^3c079ec2b7095f3f05c786ad89edc14c/d' "$nas_hashlist_with_filename"
sed -i '/^3c079ec2b7095f3f05c786ad89edc14c/d' "$nas_hashlist_uniq"
sed -i '/^3c079ec2b7095f3f05c786ad89edc14c/d' "$nas_hashlist_duplicated"

sed -i '/^62f599af1fc5ed02f4a0ba23076c0d9e/d' "$nas_hashlist"
sed -i '/^62f599af1fc5ed02f4a0ba23076c0d9e/d' "$nas_hashlist_with_filename"
sed -i '/^62f599af1fc5ed02f4a0ba23076c0d9e/d' "$nas_hashlist_uniq"
sed -i '/^62f599af1fc5ed02f4a0ba23076c0d9e/d' "$nas_hashlist_duplicated"

sed -i '/^a4c3374cb47c8ccb88032a7db564330f/d' "$nas_hashlist"
sed -i '/^a4c3374cb47c8ccb88032a7db564330f/d' "$nas_hashlist_with_filename"
sed -i '/^a4c3374cb47c8ccb88032a7db564330f/d' "$nas_hashlist_uniq"
sed -i '/^a4c3374cb47c8ccb88032a7db564330f/d' "$nas_hashlist_duplicated"

# Versison 7.3 xxh
sed -i '/^12b9ef0f6f899ba279911d838a5daa3e/d' "$nas_hashlist"
sed -i '/^12b9ef0f6f899ba279911d838a5daa3e/d' "$nas_hashlist_with_filename"
sed -i '/^12b9ef0f6f899ba279911d838a5daa3e/d' "$nas_hashlist_uniq"
sed -i '/^12b9ef0f6f899ba279911d838a5daa3e/d' "$nas_hashlist_duplicated"

sed -i '/^aa7b076cbac4bceb352cfa3d084be34f/d' "$nas_hashlist"
sed -i '/^aa7b076cbac4bceb352cfa3d084be34f/d' "$nas_hashlist_with_filename"
sed -i '/^aa7b076cbac4bceb352cfa3d084be34f/d' "$nas_hashlist_uniq"
sed -i '/^aa7b076cbac4bceb352cfa3d084be34f/d' "$nas_hashlist_duplicated"

sed -i '/^a09a7a222b94bbdf5618a18dda32e66c/d' "$nas_hashlist"
sed -i '/^a09a7a222b94bbdf5618a18dda32e66c/d' "$nas_hashlist_with_filename"
sed -i '/^a09a7a222b94bbdf5618a18dda32e66c/d' "$nas_hashlist_uniq"
sed -i '/^a09a7a222b94bbdf5618a18dda32e66c/d' "$nas_hashlist_duplicated"

sed -i '/^$/d' "$nas_hashlist"
sed -i '/^$/d' "$nas_hashlist_with_filename"
sed -i '/^$/d' "$nas_hashlist_uniq"
sed -i '/^$/d' "$nas_hashlist_duplicated"