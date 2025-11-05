which nginx || (echo "FATAL: nginx not installed"; exit 1)
killall nginx || sleep 1
nginx -g "daemon off;" &
