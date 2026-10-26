[ -f releases.json ] || {
  echo "run from the repo root" >&2
  exit 1
}

url() { echo "https://www.getax.ch/getaxpp/$1/getax$1.tar.gz"; }

last_modified() {
  # Empty when unpublished (404); errexit/pipefail must not abort the scan.
  { curl -fsIL "$(url "$1")" 2>/dev/null || true; } | tr -d '\r' | sed -n 's/^last-modified: //Ip' | tail -1
}

pin() {
  local year=$1 lm=$2 json path hash version
  echo "getax $year: fetching $(url "$year")"
  json=$(nix store prefetch-file --json --hash-type sha256 "$(url "$year")")
  path=$(jq -r .storePath <<<"$json")
  hash=$(jq -r .hash <<<"$json")
  version=$(tar xzf "$path" "getax-pp-$year/version.xml" -O |
    sed -n 's:.*<version>\(.*\)</version>.*:\1:p')
  [ -n "$version" ] || {
    echo "getax $year: no <version> in version.xml" >&2
    exit 1
  }
  jq -S --arg y "$year" --arg v "$version" --arg h "$hash" --arg lm "$lm" \
    '.[$y] = {version: $v, hash: $h, lastModified: $lm}' releases.json >releases.json.new
  mv releases.json.new releases.json
  echo "getax $year: pinned $version"
}

if [ $# -gt 0 ]; then
  for year in "$@"; do
    lm=$(last_modified "$year")
    [ -n "$lm" ] || {
      echo "getax $year: not published" >&2
      exit 1
    }
    pin "$year" "$lm"
  done
  exit 0
fi

for year in $(jq -r 'keys[]' releases.json); do
  lm=$(last_modified "$year")
  if [ -z "$lm" ]; then
    echo "getax $year: tarball gone upstream, keeping pin"
  elif [ "$lm" != "$(jq -r --arg y "$year" '.[$y].lastModified' releases.json)" ]; then
    pin "$year" "$lm"
  else
    echo "getax $year: up to date"
  fi
done

next=$(($(jq -r 'keys | max' releases.json) + 1))
lm=$(last_modified "$next")
if [ -n "$lm" ]; then pin "$next" "$lm"; else echo "getax $next: not published yet"; fi
