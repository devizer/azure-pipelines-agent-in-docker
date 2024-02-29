set -eu
function get_global_seconds() {
  theSYSTEM="${theSYSTEM:-$(uname -s)}"
  if [[ ${theSYSTEM} != "Darwin" ]]; then
      # uptime=$(</proc/uptime);                                # 42645.93 240538.58
      uptime="$(cat /proc/uptime 2>/dev/null)";                 # 42645.93 240538.58
      if [[ -z "${uptime:-}" ]]; then
        # secured, use number of seconds since 1970
        echo "$(date +%s)"
        return
      fi
      IFS=' ' read -ra uptime <<< "$uptime";                    # 42645.93 240538.58
      uptime="${uptime[0]}";                                    # 42645.93
      uptime=$(LC_ALL=C LC_NUMERIC=C printf "%.0f\n" "$uptime") # 42645
      echo $uptime
  else 
      # https://stackoverflow.com/questions/15329443/proc-uptime-in-mac-os-x
      boottime=`sysctl -n kern.boottime | awk '{print $4}' | sed 's/,//g'`
      unixtime=`date +%s`
      timeAgo=$(($unixtime - $boottime))
      echo $timeAgo
  fi
}

function Wait-For-VM() {
  local lauch_options="$1"

  local n=1
  local ok
  local startAt="$(get_global_seconds)"
  echo "startAt: $startAt"
  while [[ 1 == 1 ]]; do
    local current="$(get_global_seconds)"
    echo "current: $current"
    current="$((current-startAt))"
    current="$((15*60 - current))"
    if [[ $current -le 0 ]]; then break; fi
    echo "{#$n:$current} Waiting for ssh connection to VM on port"
    set +e
    ls xxxxxxxxxxxxxxxxxxx
    ok=1;
    set -e
    if [ $ok -eq 0 ]; then break; fi
    sleep 5
    n=$((n+1))
  done
  echo "OK: $ok"
}

Wait-For-VM stub
