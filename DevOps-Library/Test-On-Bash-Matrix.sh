. DevOps-Library.sh
for img in 3.2 4.0.44 5.0 latest; do
  Colorize Green "TEST ON BASH [$img]"
  RetryOnFail docker pull -q bash:"$img"
  docker run -t bash:"$img" bash -c 'echo BASH VERSION is [$BASH_VERSION]'
done
