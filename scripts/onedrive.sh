#   ___             ____       _            
#  / _ \ _ __   ___|  _ \ _ __(_)_   _____  
# | | | | '_ \ / _ \ | | | '__| \ \ / / _ \ 
# | |_| | | | |  __/ |_| | |  | |\ V /  __/ 
#  \___/|_| |_|\___|____/|_|  |_| \_/ \___| 
#                                           
#  
# by Stephan Raabe (2023) 
# ----------------------------------------------------- 

rclone mount --vfs-cache-mode writes  --drive-use-trash onedrive-365: ~/Documents/OneDrive
notify-send "OneDrive connected" "Microsoft OneDrive successfully mounted."
