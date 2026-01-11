. DevOps-Library.sh
for img in 3.2 4.0.44 4.1 4.2 4.3 4.4 5.0 5.1 5.2 5.3 latest; do
  Colorize Green "TEST ON BASH [$img]"
  Retry-On-Fail docker pull -q bash:"$img"
  docker run -v $PWD:/app -t bash:"$img" bash -c 'echo BASH VERSION is [$BASH_VERSION]; cd /app; 
    . DevOps-Library.sh; 
    Retry-On-Fail apk update;
    Retry-On-Fail apk add curl;
    for s in "[Test] Validate File Is Not Empty.sh" "[Test] Wait For Http.sh" "[Test] Download.sh" "[Test] Retry.sh" "[Test] ALL.sh" "[Test] Fetch S5 Dashboard API.sh"; do
      Colorize Cyan $s;
      bash "$s"
    done 
    '
  echo "____________________OK_${img}_____________________________"
done

# "[Test] Validate File Is Not Empty.sh" "[Test] Wait For Http.sh" "[Test] Download.sh" "[Test] Retry.sh"