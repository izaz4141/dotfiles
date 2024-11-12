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

if [[ "$1" == "--pull" ]]; then
    pull_from_cloud

elif [[ "$1" == "--sync" ]]; then
    sync_to_cloud
fi
