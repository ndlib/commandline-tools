#!/bin/bash
# Extracts all merged pull requests and gets the associated JIRA ticket details to
# create a markdown compatible with our CHANGELOG.md format. Assumes branches
# are named ndlib/ticketprefix-rest-of-branch-name
#
# Example usage:
#   changelog jirauser v1.0 v2.0 AIMS
#
# Example output:
#    **New features/enhancements:**
#    - Added super cool feature X ([AIMS-1](https://jira.library.nd.edu/browse/AIMS-1), [#1](https://github.com/ndlib/aims/pull/1))
#    - Added super cool feature Y ([AIMS-2](https://jira.library.nd.edu/browse/AIMS-2), [#3](https://github.com/ndlib/aims/pull/3))
#    - Added super cool feature X ([AIMS-1](https://jira.library.nd.edu/browse/AIMS-1), [#2](https://github.com/ndlib/aims/pull/2))
#
#    **Bug fixes:**
#    - Fixed super annoying bug A ([AIMS-3](https://jira.library.nd.edu/browse/AIMS-3), [#4](https://github.com/ndlib/aims/pull/4))
#
#    **Unknown type:**
#    - Fill in this summary ([#5](https://github.com/ndlib/aims/pull/5))
# Notes:
# - If you fail to log in too many times, you'll have to go to a web interface for jira,
#   logout and back in, so that you can perform the captcha.
# - This does not collapse all PR's associated with a ticket into one entry. So you will see duplicate
#   summaries if multiple PRs are associated with a single ticket. See example output



#############
# FUNCTIONS #
#############
# Gets pull and branch name for all merged pull requests for a given date range. Assumes $start and $end have been assigned with valid dates.
# Example output:
#   134,AIMS-263-feature-im-adding
#   131,AIMS-219
#   129,bugfix-AIMS-331
#   125,bugfix-AIMS-331-label-correction
get_pulls()
{
  git fetch
  git log --merges --oneline $start..$end | # Get the merges for the time frame, ex: 943ef1f Merge pull request #134 from ndlib/AIMS-263-Remove-item-from-bin
    grep "Merge pull request" | # Filter to just pull request merges
    awk '{ printf "%s,%s\n", $5, $7 }' | # Extract the pull id and branch, ex: #134,ndlib/AIMS-263-Remove-item-from-bin
    sed 's/#//g' # Remove the # from the pull id
}

# Gets the ticket type and summary from Jira. Assumes $ticket_id has been assigned with a valid ticket identifier.
# Example output:
#   Bug|This is a ticket
get_ticket()
{
  # Get the json data from the Jira API for a ticket
  ticket_data=$(curl -s GET -H "Authorization: Basic $auth" -H "Content-Type: application/json" "$jirahost/rest/api/latest/issue/$ticket_id?expand=names,renderedFields")
  # Transform it to the expected pipe delimited format of "type|summary"
  echo $ticket_data |
    jq -c '[.fields.issuetype.name, .fields.summary]' | # Grab the issue type and summary from the json, ex: ["Bug", "This is a ticket"]
    sed 's/^\[\(.*\)\]$/\1/g' | # Remove the [] from the output from jq, ex: "Bug", "This is a ticket"
    sed 's/\(\"\(.*\)\"\),\(\"\(.*\)\"\)/\2|\4/g' # Remove outer quotes and replace comma delim with pipe (just in case), ex: Bug|This is a ticket
}

print_help()
{
  cat << EOF
usage: changelog <username> <branch> <branch> <ticketprefix>

Extracts all merged pull requests between two branches or tags and gets the associated JIRA ticket details to create a markdown compatible with our CHANGELOG.md format. Assumes branches are named ndlib/ticketprefix-rest-of-branch-name

Example usage:
  changelog jirauser v1.0 v2.0 AIMS

Example output:
  **New features/enhancements:**
  - Added super cool feature X ([AIMS-1](https://jira.library.nd.edu/browse/AIMS-1), [#1](https://github.com/ndlib/aims/pull/1))
  - Added super cool feature Y ([AIMS-2](https://jira.library.nd.edu/browse/AIMS-2), [#3](https://github.com/ndlib/aims/pull/3))
  - Added super cool feature X ([AIMS-1](https://jira.library.nd.edu/browse/AIMS-1), [#2](https://github.com/ndlib/aims/pull/2))

  **Bug fixes:**
  - Fixed super annoying bug A ([AIMS-3](https://jira.library.nd.edu/browse/AIMS-3), [#4](https://github.com/ndlib/aims/pull/4))

  **Unknown type:**
  - Fill in this summary ([#5](https://github.com/ndlib/aims/pull/5))
EOF
}
#################
# END FUNCTIONS #
#################


#############
# INI/INPUT #
#############
# Print help if no arguments given
if [[ "$@" = "" ]] || [[ "$1" = "help" ]]; then
  print_help
  exit
fi

user=$1
start=$2
end=$3
prefix=$4

# Validate arguments
if [ "$user" = "" ]; then
  echo "You must provide a username to login to Jira. See '${0} help' for usage."
  exit 1
fi

if [ "$start" = "" ]; then
  echo "You must provide a starting tag or branch for comparison. See '${0} help' for usage."
  exit 1
fi

if [ "$end" = "" ]; then
  echo "You must provide an ending tag or branch for comparison. See '${0} help' for usage."
  exit 1
fi

if [ "$prefix" = "" ]; then
  echo "You must provide a ticket prefix for finding the associated Jira tickets. See '${0} help' for usage."
  exit 1
fi

# Feedback on what we're using
cat << EOF
Will login to Jira with user '$user'.
Will get merges between '$start' and '$end'.
Will look for tickets with prefix '$prefix'.

EOF

# Get the user password
echo "Enter password for $user, or hit CTRL-C to stop:"
stty -echo
read -r password
stty echo
auth=$( echo -n "$user:$password" | base64 )

bugs_array=()
features_array=()
remote=`git remote -v | grep fetch | awk '{ print $2 }' | sed 's/\.git//g'`
jirahost="https://jira.library.nd.edu"
gitorg="ndlib"

# Performa quick auth test before we repeatedly hit the API and lock the user out
auth_result=$(curl -s -o /dev/null -I -w "%{http_code}" -H "Authorization: Basic $auth" -H "Content-Type: application/json" "$jirahost/rest/api/latest/search")
if [ "$auth_result" != "200" ]; then
  echo "Authenticating with Jira failed with $auth_result. Test your login at $jirahost."
  exit 1
fi
#################
# END INI/INPUT #
#################


# Loop through each line returned by get_pulls
while read pull; do
  IFS=',' read -r -a pull_array <<< "$pull"
  pull_id=${pull_array[0]}
  branch_id=${pull_array[1]}
  pull_md="[#$pull_id]($remote/pull/$pull_id)"

  # If the ticket prefix is in the name of the branch, lookup the ticket info
  if [[ $branch_id =~ $gitorg\/$prefix ]]; then
    ticket_id=$(echo $branch_id | sed "s/$gitorg\/\(\([^-]*\)-\([^-]*\)\).*/\1/g")
    echo "Reading ticket for PR#$pull_id: $jirahost/rest/api/latest/issue/$ticket_id?expand=names,renderedFields"
    # Read ticket returned by get_ticket
    while read ticket; do
      IFS='|' read -r -a ticket_array <<< "$ticket"
      ticket_summary=${ticket_array[1]}
      ticket_type=${ticket_array[0]}
      ticket_md="[$ticket_id]($jirahost/browse/$ticket_id)"
      markdown="- $ticket_summary ($ticket_md, $pull_md)"
      if [ "$ticket_type" = "Bug" ]; then
        bugs_array+=("$markdown")
      else
        features_array+=("$markdown")
      fi
    done < <( get_ticket )
  else
    # Otherwise add it to a different section that will require user editing
    echo "Unknown ticket for PR#$pull_id. Branch name '$branch_id'"
    markdown="- Fill in this summary ($pull_md)"
    unknowns_array+=("$markdown")
  fi
done < <( get_pulls )

echo "Done! Here's your changelog:"
echo "----------------------------"
echo

echo "**New features/enhancements:**"
printf '%s\n' "${features_array[@]}"
echo
echo "**Bug fixes:**"
printf '%s\n' "${bugs_array[@]}"
echo
echo "**Unknown type:**"
printf '%s\n' "${unknowns_array[@]}"
