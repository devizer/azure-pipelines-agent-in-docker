. DevOps-Library.sh
for img in 3.2 4.0.44 4.1 4.2 4.3 4.4 5.0 5.1 5.2 5.3 latest; do
  Colorize Green "TEST ON BASH [$img]"
  RetryOnFail docker pull -q bash:"$img"
  docker run -v $PWD:/app -t bash:"$img" bash -c 'echo BASH VERSION is [$BASH_VERSION]; cd /app; set -e; bash "[Test] ALL.sh"; bash "[Test] Fetch S5 Dashboard API.sh"'
  echo "____________________OK_${img}_____________________________"
done
