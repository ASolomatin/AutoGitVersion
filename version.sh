#!/usr/bin/env bash

DEVELOPMENT_BRANCH=${AGV_MAIN_BRANCH-"main"}
STAGING_BRANCH=${AGV_STAGING_BRANCH-"staging"}
PRODUCTION_BRANCH=${AGV_STAGING_BRANCH-"production"}

MERGE_BRANCH_MATCH_EXPRESSIONS=(
    "\"^Merge branch '([^']*)' into '([^']*)'\" 1 2"                            # GitLab
    "\"^Merge (branch|tag) '([^']*)'( of [^ ]+)?( into ([^ ]+))?\" 2 5"         # Default
    "\"^Finish ([^ ]*)( into ([^ ]*))?\" 1 3"                                   # SmartGit
    "\"^Merge pull request #(\d+) (from|in) (.*) from ([^ ]*) to ([^ ]*)\" 4 5" # BitBucketPull
    "\"^Pull request #(\d+).* Merge in (.*) from ([^ ]*) to ([^ ]*)\" 3 4"      # BitBucketPullv7
    "\"^Merge pull request #(\d+) (from|in) ([^ ]*)( into ([^ ]*))?\" 3 5"      # GitHubPull
    "\"^Merge remote-tracking branch '([^ ]*)'( into ([^ ]*))?\" 1 3"           # RemoteTracking
)

MERGE_BRANCH_SOURCES=(
    "\"^(${DEVELOPMENT_BRANCH})$\" ${STAGING_BRANCH}" # Release to stage
    "\"^(${STAGING_BRANCH})$\" ${PRODUCTION_BRANCH}"  # Release to production
    "\"^(.*)$\" ${DEVELOPMENT_BRANCH}"                # Merge featur branch
)

# Internal

INCREMENT_NONE=4
INCREMENT_BUILD=3
INCREMENT_PATCH=2
INCREMENT_MINOR=1
INCREMENT_MAJOR=0

get_current_branch() {
    local branch_name
    branch_name="$(git symbolic-ref HEAD 2>/dev/null)"
    branch_name=${branch_name##refs/heads/}
    echo "$branch_name"
}

load_history() {
    local -n arr_history=$1

    arr_history=()

    local commit_hash
    while IFS= read -r commit_hash; do
        arr_history+=("$commit_hash")
    done < <(git log --pretty=format:"%H" && printf '\n')

    array_reverse arr_history
}

is_commit_major() {
    local commit_hash=$1
    local semver_match="^\+semver ?: ?([^ ]+)"

    local message_line
    while IFS= read -r message_line; do
        if [[ $message_line =~ $semver_match ]]; then
            local semver_tag=${BASH_REMATCH[1]}

            if [ "${semver_tag}" == "major" ]; then
                return 0
            fi
        fi
    done < <(git log -1 --pretty="%B" "$commit_hash")

    return 1
}

get_commit_branch() {
    local commit_hash=$1
    local arr_branches=()

    local branch_name
    while IFS= read -r branch_name; do
        arr_branches+=("$branch_name")
    done < <(git branch --format "%(refname:short)" --contains "$commit_hash")

    if array_contains arr_branches $DEVELOPMENT_BRANCH; then
        echo $DEVELOPMENT_BRANCH
    elif array_contains arr_branches $STAGING_BRANCH; then
        echo $STAGING_BRANCH
    elif array_contains arr_branches $PRODUCTION_BRANCH; then
        echo $PRODUCTION_BRANCH
    else
        get_current_branch
    fi
}

load_releases() {
    local -n releases=$1

    releases=()

    local source_branch
    local target_branch
    local merge_info
    while IFS= read -r merge_info; do
        local -a arr_info="($merge_info)"
        local commit_hash=${arr_info[0]}
        local commit_parrent=${arr_info[2]}
        local commit_subject=${arr_info[3]}

        if match_merge_branches "${commit_subject}" source_branch target_branch; then
            if [ "${source_branch}" == "${DEVELOPMENT_BRANCH}" ] && [ "${target_branch}" == "${STAGING_BRANCH}" ]; then
                if is_commit_major "$commit_hash" || is_commit_major "$commit_parrent"; then
                    # shellcheck disable=SC2034  # It's by refname
                    releases["$commit_parrent"]=$INCREMENT_MAJOR
                else
                    # shellcheck disable=SC2034  # It's by refname
                    releases["$commit_parrent"]=$INCREMENT_MINOR
                fi
                # shellcheck disable=SC2034  # It's by refname
                releases["$commit_hash"]=$INCREMENT_NONE
            fi
        fi
    done < <(git log --merges --pretty="%H %P \"%s\"" ${STAGING_BRANCH})

    while IFS= read -r merge_info; do
        local -a arr_info="($merge_info)"
        local commit_hash=${arr_info[0]}
        local commit_subject=${arr_info[1]}

        if match_merge_branches "${commit_subject}" source_branch target_branch; then
            if [ "${source_branch}" == "${STAGING_BRANCH}" ] && [ "${target_branch}" == "${PRODUCTION_BRANCH}" ]; then
                # shellcheck disable=SC2034  # It's by refname
                releases["$commit_hash"]=$INCREMENT_NONE
            fi
        fi
    done < <(git log --merges --pretty="%H \"%s\"" ${PRODUCTION_BRANCH})
}

try_guess_merge_target() {
    local source=$1

    local source_template
    for source_template in "${MERGE_BRANCH_SOURCES[@]}"; do
        local -a arr_template="($source_template)"

        local template=${arr_template[0]}
        local target=${arr_template[1]}

        if [[ $source =~ $template ]]; then
            echo "$target"

            return 0
        fi
    done

    return 1
}

match_merge_branches() {
    local message=$1
    local -n source=$2
    local -n target=$3

    local expression_template
    for expression_template in "${MERGE_BRANCH_MATCH_EXPRESSIONS[@]}"; do
        local -a arr_expression="($expression_template)"

        local expression=${arr_expression[0]}
        local source_match=${arr_expression[1]}
        local target_match=${arr_expression[2]}

        if [[ $message =~ $expression ]]; then
            source=${BASH_REMATCH[$source_match]}
            target=${BASH_REMATCH[$target_match]}

            if [ -z "${target}" ]; then
                target=$(try_guess_merge_target "$source")
            fi

            return 0
        fi
    done

    return 1
}

array_reverse() {
    local -n array_r=$1
    local min=0
    local max=$((${#array_r[@]} - 1))
    local x

    while [[ min -lt max ]]; do
        x="${array_r[$min]}"
        array_r[$min]="${array_r[$max]}"
        array_r[$max]="$x"

        ((min++, max--))
    done
}

array_contains() {
    local -n array=$1
    local value=$2

    local element
    for element in "${array[@]}"; do
        if [ "${element}" == "${value}" ]; then
            return 0
        fi
    done

    return 1
}

# Increments version by level
increment() {
    local -n arr_version=$1
    local level=$2

    if [[ level -lt $INCREMENT_NONE ]]; then
        ((arr_version[level]++))

        while [[ level -lt $INCREMENT_BUILD ]]; do
            ((level++, arr_version[level] = 0))
        done
    fi
}

# Computes increment level for single commit based on level map and branch
get_increment_level() {
    local -n level_map=$1
    local commit_hash=$2
    local branch=$3
    local already_has_major=$4

    if [ ${level_map["$commit_hash"]+_} ]; then
        if $already_has_major; then
            echo $INCREMENT_NONE
        else
            echo "${level_map["$commit_hash"]}"
        fi
    else
        case $branch in

        "$STAGING_BRANCH")
            echo $INCREMENT_PATCH
            ;;

        "$PRODUCTION_BRANCH")
            echo $INCREMENT_PATCH
            ;;

        *)
            if ! $already_has_major && is_commit_major "$commit_hash"; then
                echo $INCREMENT_MAJOR
            else
                echo $INCREMENT_BUILD
            fi
            ;;
        esac
    fi
}

format_version() {
    local -n arr_version=$1
    local branch=$2

    local vMajor=${arr_version[0]}
    local vMinor=${arr_version[1]}
    local vPatch=${arr_version[2]}
    local vBuild=${arr_version[3]}

    case $branch in

    "$DEVELOPMENT_BRANCH")
        echo "${vMajor}.${vMinor}.${vPatch}-alpha.${vBuild}"
        ;;

    "$STAGING_BRANCH")
        echo "${vMajor}.${vMinor}.${vPatch}-beta"
        ;;

    "$PRODUCTION_BRANCH")
        echo "${vMajor}.${vMinor}.${vPatch}"
        ;;

    *)
        local feature_name
        feature_name=$(echo "$branch" | sed -r 's/[^a-zA-Z0-9]+/./g')
        echo "${vMajor}.${vMinor}.${vPatch}-${feature_name}.${vBuild}"
        ;;
    esac
}

compute_version() {
    local -a hash_history
    local -A release_hash_map
    local branch
    # shellcheck disable=SC2034  # It's used by refname
    local version=(0 0 0 0)

    branch=$(get_current_branch)

    if [ "$branch" = "$DETACHED" ]; then
        echo "HEAD is detached"
        exit 1
    fi

    load_history hash_history
    load_releases release_hash_map

    local commit_hash
    local is_release
    local has_major_increments=false
    for commit_hash in "${hash_history[@]}"; do
        local increment_level
        local commit_branch
        commit_branch=$(get_commit_branch "$commit_hash")
        increment_level=$(get_increment_level release_hash_map "$commit_hash" "$commit_branch" "$has_major_increments")
        is_release=$([ ${release_hash_map["$commit_hash"]+_} ] && echo true || echo false)

        if $is_release; then
            has_major_increments=false
        else
            if [[ $increment_level -eq $INCREMENT_MAJOR ]]; then
                has_major_increments=true
            fi
        fi

        increment version "$increment_level"
    done

    if [ "$branch" != "$STAGING_BRANCH" ] && [ "$branch" != "$PRODUCTION_BRANCH" ] && ! $has_major_increments; then
        ((version[INCREMENT_MINOR]++))
    fi

    format_version version "$branch"
}

compute_version

exit 0
