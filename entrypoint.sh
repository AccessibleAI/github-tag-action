#!/bin/bash

set -o pipefail
# config
default_semvar_bump=${DEFAULT_BUMP:-none}
with_v=${WITH_V:-true}
release_branches=${RELEASE_BRANCHES:-master,main}
source=${SOURCE:-.}
dryrun=${DRY_RUN:-false}
initial_version=${INITIAL_VERSION:-0.0.0}
tag_context=${TAG_CONTEXT:-repo}
verbose=${VERBOSE:-true}
dirty=${VERBOSE:-false}

cd ${GITHUB_WORKSPACE}/${source}
current_branch=$(git rev-parse --abbrev-ref HEAD)
suffix=${current_branch}
log=$(git log -1 --pretty='%B')

echo "*** CONFIGURATION ***"
echo -e "\tDEFAULT_BUMP: ${default_semvar_bump}"
echo -e "\tWITH_V: ${with_v}"
echo -e "\tRELEASE_BRANCHES: ${release_branches}"
echo -e "\tSOURCE: ${source}"
echo -e "\tDRY_RUN: ${dryrun}"
echo -e "\tINITIAL_VERSION: ${initial_version}"
echo -e "\tTAG_CONTEXT: ${tag_context}"
echo -e "\tPRERELEASE_SUFFIX: ${suffix}"
echo -e "\tVERBOSE: ${verbose}"

bumped="false"
pre_release="true"
IFS=',' read -ra branch <<< "$release_branches"
for b in "${branch[@]}"; do
    echo "Is $b a match for ${current_branch}"
    if [[ "${current_branch}" =~ $b ]]
    then
        pre_release="false"
        suffix="rc"
    fi
done
echo "pre_release = $pre_release - branch is not master/main"

# fetch tags
git fetch --tags


# echo log if verbose is wanted
if $verbose
then
  echo "log: $log"
fi

echo "configure part variable"
case "$log" in
    *#major*        )  part="major";;
    *#minor*        )  part="minor";;
    *#patch*        )  part="patch";;
    *#hotfix*       )  part="patch";;
    *#premajor*     )  part="premajor";;
    *#preminor*     )  part="preminor";;
    *#prehotfix*    )  part="prerelease";;
    *#prerelease*   )  part="prerelease";;
    *#rc*           )  part="prerelease";;
    *#dirty*        )  new="dirty-$(echo $RANDOM | md5sum | head -c 10)"; part="dirty";dirty="true";;
    *#custom*       )  custom_tag=$(echo $log | cut -d "[" -f2 | cut -d "]" -f1);;
    *#none*         )  echo "Default bump was set to none. Skipping..."; echo ::set-output name=new_tag::$tag; echo ::set-output name=tag::$tag; exit 0;;
    * )
        if [ "$default_semvar_bump" == "none" ]; then
            echo "Default bump was set to none. Skipping..."; echo ::set-output name=new_tag::$tag; echo ::set-output name=tag::$tag; exit 0
        else
            part=$default_semvar_bump
        fi
        ;;
esac
# get latest tag that looks like a semver (with or without v)
echo "configure tag variable"
if $pre_release; then
    tag=$(git for-each-ref --sort=-v:refname --format '%(refname:lstrip=2)' | grep -E "^v?[0-9]+\.[0-9]+\.[0-9]+(-$suffix.*)?$" | grep $suffix | head -n1)
    if [ -z "$tag" ]; then #get last from branch. if doesnt exist take last tag from main branch
        tag=$(git for-each-ref --sort=-v:refname --format '%(refname:lstrip=2)' | grep -E "^v?[0-9]+\.[0-9]+\.[0-9]?$" | head -n1)
    fi
elif ! $pre_release; then
    if [[ "$part" =~ ^("pre")$ ]]; then
        tag=$(git for-each-ref --sort=-v:refname --format '%(refname:lstrip=2)' | grep -E "^v?[0-9]+\.[0-9]+\.[0-9]+(-$suffix.*)?$" | grep $suffix | head -n1)
    else
        tag=$(git for-each-ref --sort=-v:refname --format '%(refname:lstrip=2)' | grep -E "^v?[0-9]+\.[0-9]+\.[0-9]+(-$suffix.*)?$" | grep -v $suffix | head -n1)
    fi
fi

if [ -z "$tag" ]; then
    tag=${initial_version}
fi

# get current commit hash for tag
tag_commit=$(git rev-list -n 1 $tag)

# get current commit hash
commit=$(git rev-parse HEAD)

if [ "$tag_commit" == "$commit" ]; then
    echo "No new commits since previous tag. Skipping..."
    echo ::set-output name=tag::$tag
    exit 0
fi
echo "semver -i $part $tag --preid $suffix"
new=$(semver -i $part $tag --preid $suffix)

if $pre_release && ! $dirty; then
    if ! grep -q $suffix <<< $new; then #if minor/major or first tag etc and no suffix now
        if [[ $part == *"major"* ]]; then
            new="$new-$suffix"
        elif [[ "$part" =~ ^("minor"|"patch")$ ]]; then
            new="$(semver -i $part $tag)-$suffix"
        fi
        # fi
    fi
fi

if $with_v && ! $dirty
then
    new="v$new"
fi

if [ ! -z $custom_tag ]
then
    new="$custom_tag"
fi

echo -e "Bumping Tag ${tag} \n\tNew tag ${new}"

# set outputs
echo ::set-output name=tag::$tag
echo ::set-output name=new_tag::$new
echo ::set-output name=log::$log
echo ::set-output name=part::$part

# use dry run to determine the next tag
if $dryrun
then
    echo ::set-output name=tag::$tag
    exit 0
fi

# create local git tag
git tag $new

# push new tag ref to github
dt=$(date '+%Y-%m-%dT%H:%M:%SZ')
full_name=$GITHUB_REPOSITORY
git_refs_url=$(jq .repository.git_refs_url $GITHUB_EVENT_PATH | tr -d '"' | sed 's/{\/sha}//g')

echo "$dt: **pushing tag $new to repo $full_name"

git_refs_response=$(
curl -s -X POST $git_refs_url \
-H "Authorization: token $GITHUB_TOKEN" \
-d @- << EOF

{
  "ref": "refs/tags/$new",
  "sha": "$commit"
}
EOF
)

git_ref_posted=$( echo "${git_refs_response}" | jq .ref | tr -d '"' )

echo "::debug::${git_refs_response}"
if [ "${git_ref_posted}" = "refs/tags/${new}" ]; then
  echo ::set-output name=bumped::true
  echo "bumped=true"
  echo "log=$log"
  echo "new_tag=$new"
  echo "tag=$tag"
  echo "part=$part"
  exit 0
else
  echo "::error::Tag was not created properly."
  exit 1
fi
