#!/usr/bin/env bash

# The reason I checked for a clean repo is that wanted to ensure I was
# in a mental mode of "Preparing for a Release". To me, that implies a
# moment when active change of the code has stopped and I'm working to
# now promote a build.
clean_repo=$(git status --porcelain)
if [ -n "$clean_repo" ]; then
  printf "Unable to tag current build; The git repository has changes. Please review:\n\n"
  printf "$clean_repo\n" 1>&2
  exit 1
fi

# Determine the root directory for this git repository
DIR="$( cd "$(git rev-parse --show-toplevel)" && pwd )"
next_build_identifier=$(next-build-identifier.sh)

# Write the next build identifier to the VERSION file
echo "$next_build_identifier" > $DIR/VERSION
git add VERSION
git commit -m "Bumping build identifier to \"$next_build_identifier\""
git tag $next_build_identifier -a -m "Annotating build identifier \"$next_build_identifier\""
git push --tags
git push origin
