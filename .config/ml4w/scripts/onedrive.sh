#   ___             ____       _            
#  / _ \ _ __   ___|  _ \ _ __(_)_   _____  
# | | | | '_ \ / _ \ | | | '__| \ \ / / _ \ 
# | |_| | | | |  __/ |_| | |  | |\ V /  __/ 
#  \___/|_| |_|\___|____/|_|  |_| \_/ \___| 
#                                           
#  
#
# ----------------------------------------------------- 
pull_from_cloud() {
    rclone -i -P -v sync onedrive:Documents ~/Documents/OneDrive
    notify-send "OneDrive connected" "Successfully pulled file from the OneDrive"
}

sync_to_cloud() {
    rclone -i -P -v sync  ~/Documents/OneDrive onedrive:Documents
    notify-send "OneDrive connected" "Successfully synced local to OneDrive"
}

mount_from_cloud() {
    rclone mount onedrive:Documents ~/Documents/OneDrive --vfs-cache-mode writes &
    notify-send "OneDrive mounted" "Successfully mounted OneDrive to virtual local filesystem"
}


case $1 in
    --pull)
        pull_from_cloud
    ;;
    --sync)
        sync_to_cloud
    ;;
    --mount)
        mount_from_cloud
    ;;
    *)
        echo "Valid flags are --pull, --sync, and --mount"
    ;;
esac
