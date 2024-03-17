c=0; while true; do c=$((c+1)); free -m | awk -v counter=$c 'NR==2{print "[MEMORY" counter "] Total: " $2 " Mb; Used: " $3 " Mb" "; Available: " $7 " Mb"}'; sleep 1; done

