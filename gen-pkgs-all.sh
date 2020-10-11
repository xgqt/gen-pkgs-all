#!/bin/sh

# This file is part of gen-pkgs-all.

# gen-pkgs-all is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# gen-pkgs-all is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with gen-pkgs-all.  If not, see <https://www.gnu.org/licenses/>.


# If you have enough time fire up a VM,
# remove "for speed" and run this  ;-)


trap 'exit 128' INT
export PATH


# Maybe: /home/xy/.cache/eselect-repo/repositories.xml
repo_urls="$(eselect repository list | grep -i git | cut -d "(" -f 2 | sed 's/)//' | sed 's/cgit/anongit/' | sed 's/\/dev/\/git\/dev/' | sed 's/\/proj/\/git\/proj/' | sed 's/\/user/\/git\/user/' | sort)"
num_repos="$(echo "${repo_urls}" | wc -l)"
cnt_repos=$((0))


[ -d ./public/overlays ] && rm -rfd ./public/overlays
[ -f ./public/index.html ] && rm ./public/index.html 
mkdir -p ./public/overlays
cd ./public || exit 1


cat >> ./index.html << BLOCK
<!DOCTYPE html>

<html>
<head>
    <meta charset="utf-8" />
    <meta name="generator" content="GitLab Pages" />
    <meta name="description" content="src_prepare" />
    <meta name="keywords" content="src_prepare" />
    <meta name="author" content="src_prepare" />
    <title>Gen-PKGs-All</title>
    <link rel="stylesheet" href="assets/styles/main.css" />
</head>
<body>
<div id="main">
<h1>
    Package report generated each day at 01:00 AM (or otherwise by GitLab pipeline schedule)
</h1>
<ul>
    <li>
        <a href="https://gitlab.com/src_prepare/gen-pkgs-all">
             Git repo
        </a>
    </li>
    <li>
        <a href="https://gitlab.com/src_prepare/gen-pkgs-all/-/jobs">
           Jobs
        </a>
    </li>
    <li>
        <a href="https://gitlab.com/src_prepare/gen-pkgs-all/-/pipeline_schedules">
           Pipeline Schedules
        </a>
    </li>
</ul>
<p>
    Curent project status:
    <a href="https://gitlab.com/src_prepare/gen-pkgs-all/pipelines">
        <img src="https://gitlab.com/src_prepare/gen-pkgs-all/badges/master/pipeline.svg">
    </a>
    <a href="https://gitlab.com/src_prepare/gen-pkgs-all/commits/master.atom">
        <img src="https://gitlab.com/src_prepare/badge/-/raw/master/feed-atom-orange.svg">
    </a>
</p>
BLOCK

cd ./overlays || exit 1
git clone https://gitlab.com/src_prepare/gen-pkgs || exit 1

# For speed we have to remove repoman and euscan
cd gen-pkgs || exit 1
sed -i 's/repoman/true/' gen-pkgs.sh || exit 1
sed -i 's/euscan/true/' gen-pkgs.sh || exit 1
rm -dfr .git .gitignore .gitlab-ci.yml
rm -dfr LICENSE README.md
cd .. || exit 1


for url in ${repo_urls}
do
    cnt_repos=$((cnt_repos+1))
    repo=$(basename "${url}" | sed 's/\.git//')
    repo_header="Repo ${cnt_repos}/${num_repos}: ${repo}"
    echo "${repo_header}"
    cp -r gen-pkgs "${repo}"
    cat >> ../index.html <<BLOCK
<p>
 <a target="_blank" href="./overlays/${repo}/public/index.html">
  ${repo_header} (${url})
 </a>
</p>
BLOCK
    cd "${repo}" || continue
    timeout 1m sh ./gen-pkgs.sh "${url}" &
    cd - || exit 1
    # Linit to 10 or $(nproc)
    if [ "$(jobs -p | wc -l)" -gt 10 ]
    then
        for j in $(jobs -p)
        do
            wait "${j}"
        done
    fi
done

for j in $(jobs -p)
do
    wait "${j}"
done

cat >> ../index.html << BLOCK
<p>
    Total number of repos: ${num_repos}
</p>
<p>
    Generated on: $(date)
</p>
</div>
</body>
</html>
BLOCK

rm -rfd gen-pkgs
