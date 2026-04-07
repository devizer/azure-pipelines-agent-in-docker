MY_UUID="2b0f72d6-1c52-43de-93b4-b9345ae9a656"

Compress-Folder-as-Compressed-VMDK() {
    if [ "$#" -lt 2 ]; then
        echo "Usage: Compress-Folder-as-Compressed-VMDK <output_image> <source_folder> [compress_mode]"
        return 1
    fi

    local IMAGE_NAME="$1"
    local SRC_FOLDER="$2"
    local LABEL_PREFIX="$3"
    local COMPRESS_MODE="${4:-zstd:6}"
    local LABEL="${LABEL_PREFIX}-${COMPRESS_MODE//:/-}"

    # 1. Pre-create the VMDK image using qemu-img to ensure it is sparse
    qemu-img create -f vmdk "$IMAGE_NAME" 10000M
    Say "Compressing '$SRC_FOLDER' (size is $(Format-Thousand "$(Get-Folder-Size "$SRC_FOLDER")") bytes)"

    # 2. Use guestfish and capture all output to extract the UUID
    local GUEST_OUTPUT
    set +x;
    export LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1
    GUEST_OUTPUT=$(sudo guestfish -a "$IMAGE_NAME" <<EOF
      run
      
      # 3. Partitioning
      part-init /dev/sda mbr
      part-add /dev/sda p 2048 -1
      
      # 4. Create Btrfs with compatibility features
      # mkfs-opts btrfs /dev/sda1 label:$LABEL features:^extref,^skinny-metadata
      debug sh "ls /bin /sbin /usr/bin /usr/sbin"
      debug sh "mkfs.btrfs -L '$LABEL' -O ^extref,^skinny-metadata -U '$MY_UUID' /dev/sda1"


      # btrfs-set-uuid /dev/sda1 $MY_UUID


      
      # 5. Mount with forced compression and options
      mount-options "compress-force=$COMPRESS_MODE,nodiratime,noatime" /dev/sda1 /
      
      # 6. Copy source folder content to the root
      copy-in "$SRC_FOLDER/." /
      
      # 7. Output prefix and UUID on separate lines
      echo "VOLUME_UUID:"
      vfs-uuid /dev/sda1
      
      sync
      exit
EOF
)
    
    sudo chown $USER:$USER "$IMAGE_NAME"

    # 9. Final messages using your custom functions
    Say "Compression '$SRC_FOLDER' complete as [$IMAGE_NAME] (compressed size is $(Format-Thousand "$(Get-File-Size "$IMAGE_NAME")") bytes)"

    # 8. Join prefix with the next line and store in a GLOBAL variable
    BUILT_VOLUME_UUID=$(echo "$GUEST_OUTPUT" | sed -n '/VOLUME_UUID:/{N;s/\n//;p;}')
    BUILT_VOLUME_UUID="$(echo "$BUILT_VOLUME_UUID" | awk -F":" '{print $2}')"
    echo "Volume UUID is stored in the BUILT_VOLUME_UUID environment variable: [$BUILT_VOLUME_UUID]"
}

Say --Reset-Stopwatch

sudo rm -rf /usr/share/dotnet
export SKIP_DOTNET_DEPENDENCIES=True
export DOTNET_VERSIONS="6.0 8.0 10.0"
export DOTNET_TARGET_DIR=/usr/share/dotnet
Run-Remote-Script https://raw.githubusercontent.com/devizer/test-and-build/master/lab/install-DOTNET.sh


level=9
  Compress-Folder-as-Compressed-VMDK $SYSTEM_ARTIFACTSDIRECTORY/dotnet-6.0-8.0-10.0.zstd${level}.vmdk /usr/share/dotnet dotnet zstd:${level}
# Compress-Folder-as-Compressed-VMDK $SYSTEM_ARTIFACTSDIRECTORY/dotnet-6.0-8.0-10.0.lzo.vmdk          /usr/share/dotnet dotnet lzo
