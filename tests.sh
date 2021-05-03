#!/usr/bin/env bash

oneTimeSetUp() {
    test_directory=$(mktemp -d)
    current_directory=$PWD
    cd "$test_directory" || exit
}

oneTimeTearDown() {
    # shellcheck disable=SC2164
    cd "$current_directory"
    rm -rf "$test_directory"
}

setUp() {
    git init > /dev/null
    git commit --allow-empty -m Initial > /dev/null
    git checkout -b staging > /dev/null 2>&1
    git checkout -b production > /dev/null 2>&1
    git checkout master > /dev/null 2>&1
}

tearDown() {
    rm -rf "${test_directory}/.git"
}

version() {
    eval "${current_directory}/version.sh"
}

testInitial() {
    assertEquals "v0.1.0-alpha.1" "$(version)"
    git checkout staging > /dev/null 2>&1
    assertEquals "v0.0.0-beta" "$(version)"
    git checkout production > /dev/null 2>&1
    assertEquals "v0.0.0" "$(version)"
}

testSimpleCommit() {
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    assertEquals "v0.1.0-alpha.2" "$(version)"
}

testFeature() {
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    git checkout -b feature/DummyFeature > /dev/null 2>&1
    assertEquals "v0.1.0-feature_DummyFeature.2" "$(version)"
    git commit --allow-empty -m FeatureCommit1 > /dev/null
    assertEquals "v0.1.0-feature_DummyFeature.3" "$(version)"
    git checkout master > /dev/null 2>&1
    assertEquals "v0.1.0-alpha.2" "$(version)"
    git commit --allow-empty -m SimpleCommit2 > /dev/null
    assertEquals "v0.1.0-alpha.3" "$(version)"
    git merge feature/DummyFeature --no-ff --no-edit > /dev/null
    assertEquals "v0.1.0-alpha.5" "$(version)"
}

testMajorCommit() {
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    assertEquals "v0.1.0-alpha.2" "$(version)"
    git commit --allow-empty -m MajorCommit -m "+semver: major" > /dev/null
    assertEquals "v1.0.0-alpha.0" "$(version)"
    git commit --allow-empty -m SimpleCommit2 > /dev/null
    assertEquals "v1.0.0-alpha.1" "$(version)"
}

testMultipleMajorCommits() {
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    assertEquals "v0.1.0-alpha.2" "$(version)"
    git commit --allow-empty -m MajorCommit1 -m "+semver: major" > /dev/null
    assertEquals "v1.0.0-alpha.0" "$(version)"
    git commit --allow-empty -m SimpleCommit2 > /dev/null
    assertEquals "v1.0.0-alpha.1" "$(version)"
    git commit --allow-empty -m MajorCommit2 -m "+semver: major" > /dev/null
    assertEquals "v1.0.0-alpha.2" "$(version)"
    git commit --allow-empty -m SimpleCommit2 > /dev/null
    assertEquals "v1.0.0-alpha.3" "$(version)"
}

testFeatureWithMajorCommitOrder1() {
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    git checkout -b feature/DummyFeature > /dev/null 2>&1
    assertEquals "v0.1.0-feature_DummyFeature.2" "$(version)"
    git commit --allow-empty -m MajorCommit -m "+semver: major" > /dev/null
    assertEquals "v1.0.0-feature_DummyFeature.0" "$(version)"
    git checkout master > /dev/null 2>&1
    assertEquals "v0.1.0-alpha.2" "$(version)"
    sleep 1
    git commit --allow-empty -m SimpleCommit2 > /dev/null
    assertEquals "v0.1.0-alpha.3" "$(version)"
    git merge feature/DummyFeature --no-ff --no-edit > /dev/null
    assertEquals "v1.0.0-alpha.2" "$(version)"
}

testFeatureWithMajorCommitOrder2() {
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    git checkout -b feature/DummyFeature > /dev/null 2>&1
    assertEquals "v0.1.0-feature_DummyFeature.2" "$(version)"
    git checkout master > /dev/null 2>&1
    assertEquals "v0.1.0-alpha.2" "$(version)"
    git commit --allow-empty -m SimpleCommit2 > /dev/null
    assertEquals "v0.1.0-alpha.3" "$(version)"
    git checkout feature/DummyFeature > /dev/null 2>&1
    sleep 1
    git commit --allow-empty -m MajorCommit -m "+semver: major" > /dev/null
    assertEquals "v1.0.0-feature_DummyFeature.0" "$(version)"
    git checkout master > /dev/null 2>&1
    git merge feature/DummyFeature --no-ff --no-edit > /dev/null
    assertEquals "v1.0.0-alpha.1" "$(version)"
}

testFeatureAfterMajorCommit() {
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    git checkout -b feature/DummyFeature > /dev/null 2>&1
    assertEquals "v0.1.0-feature_DummyFeature.2" "$(version)"
    git commit --allow-empty -m FeatureCommit1 > /dev/null
    assertEquals "v0.1.0-feature_DummyFeature.3" "$(version)"
    git checkout master > /dev/null 2>&1
    assertEquals "v0.1.0-alpha.2" "$(version)"
    sleep 1
    git commit --allow-empty -m MajorCommit -m "+semver: major" > /dev/null
    assertEquals "v1.0.0-alpha.0" "$(version)"
    git merge feature/DummyFeature --no-ff --no-edit > /dev/null
    assertEquals "v1.0.0-alpha.1" "$(version)"
}

testReleaseOnStage() {
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    assertEquals "v0.1.0-alpha.2" "$(version)"
    git checkout staging > /dev/null 2>&1
    assertEquals "v0.0.0-beta" "$(version)"
    git merge master --no-ff --no-edit > /dev/null
    assertEquals "v0.1.0-beta" "$(version)"
    git checkout master > /dev/null 2>&1
    assertEquals "v0.2.0-alpha.0" "$(version)"
    git commit --allow-empty -m SimpleCommit2 > /dev/null
    assertEquals "v0.2.0-alpha.1" "$(version)"
}

testMultipleReleaseOnStage() {
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    git checkout staging > /dev/null 2>&1
    git merge master --no-ff --no-edit > /dev/null
    assertEquals "v0.1.0-beta" "$(version)"
    git checkout master > /dev/null 2>&1
    git commit --allow-empty -m SimpleCommit2 > /dev/null
    assertEquals "v0.2.0-alpha.1" "$(version)"
    git checkout staging > /dev/null 2>&1
    git merge master --no-ff --no-edit > /dev/null
    assertEquals "v0.2.0-beta" "$(version)"
    git checkout master > /dev/null 2>&1
    git commit --allow-empty -m SimpleCommit3 > /dev/null
    assertEquals "v0.3.0-alpha.1" "$(version)"
}

testMajorReleaseOnStage() {
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    assertEquals "v0.1.0-alpha.2" "$(version)"
    git checkout staging > /dev/null 2>&1
    assertEquals "v0.0.0-beta" "$(version)"
    git merge master --no-ff --no-edit -m "Merge branch 'master' into 'staging'" -m "+semver: major" > /dev/null
    assertEquals "v1.0.0-beta" "$(version)"
    git checkout master > /dev/null 2>&1
    assertEquals "v1.1.0-alpha.0" "$(version)"
    git commit --allow-empty -m SimpleCommit2 > /dev/null
    assertEquals "v1.1.0-alpha.1" "$(version)"
}

testReleaseOnStageAfterMajorCommit() {
    git commit --allow-empty -m MajorCommit -m "+semver: major" > /dev/null
    assertEquals "v1.0.0-alpha.0" "$(version)"
    git checkout staging > /dev/null 2>&1
    assertEquals "v0.0.0-beta" "$(version)"
    git merge master --no-ff --no-edit > /dev/null
    assertEquals "v1.0.0-beta" "$(version)"
    git checkout master > /dev/null 2>&1
    assertEquals "v1.1.0-alpha.0" "$(version)"
    git commit --allow-empty -m SimpleCommit2 > /dev/null
    assertEquals "v1.1.0-alpha.1" "$(version)"
}

testReleaseOnStageAfterMajorAndSimpleCommit() {
    git commit --allow-empty -m MajorCommit -m "+semver: major" > /dev/null
    assertEquals "v1.0.0-alpha.0" "$(version)"
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    assertEquals "v1.0.0-alpha.1" "$(version)"
    git checkout staging > /dev/null 2>&1
    assertEquals "v0.0.0-beta" "$(version)"
    git merge master --no-ff --no-edit > /dev/null
    assertEquals "v1.0.0-beta" "$(version)"
    git checkout master > /dev/null 2>&1
    assertEquals "v1.1.0-alpha.0" "$(version)"
    git commit --allow-empty -m SimpleCommit2 > /dev/null
    assertEquals "v1.1.0-alpha.1" "$(version)"
}

testFeatureAfterReleaseOnStage() {
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    assertEquals "v0.1.0-alpha.2" "$(version)"
    git checkout staging > /dev/null 2>&1
    assertEquals "v0.0.0-beta" "$(version)"
    git merge master --no-ff --no-edit > /dev/null
    assertEquals "v0.1.0-beta" "$(version)"
    git checkout master > /dev/null 2>&1
    assertEquals "v0.2.0-alpha.0" "$(version)"
    git checkout -b feature/DummyFeature > /dev/null 2>&1
    assertEquals "v0.2.0-feature_DummyFeature.0" "$(version)"
    sleep 1
    git commit --allow-empty -m FeatureCommit1 > /dev/null
    assertEquals "v0.2.0-feature_DummyFeature.1" "$(version)"
    git checkout master > /dev/null 2>&1
    git merge feature/DummyFeature --no-ff --no-edit > /dev/null
    assertEquals "v0.2.0-alpha.2" "$(version)"
}

testFeatureAfterMajorReleaseOnStage() {
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    assertEquals "v0.1.0-alpha.2" "$(version)"
    git checkout staging > /dev/null 2>&1
    assertEquals "v0.0.0-beta" "$(version)"
    git merge master --no-ff --no-edit -m "Merge branch 'master' into 'staging'" -m "+semver: major" > /dev/null
    assertEquals "v1.0.0-beta" "$(version)"
    git checkout master > /dev/null 2>&1
    assertEquals "v1.1.0-alpha.0" "$(version)"
    git checkout -b feature/DummyFeature > /dev/null 2>&1
    assertEquals "v1.1.0-feature_DummyFeature.0" "$(version)"
    sleep 1
    git commit --allow-empty -m FeatureCommit1 > /dev/null
    assertEquals "v1.1.0-feature_DummyFeature.1" "$(version)"
    git checkout master > /dev/null 2>&1
    git merge feature/DummyFeature --no-ff --no-edit > /dev/null
    assertEquals "v1.1.0-alpha.2" "$(version)"
}

testReleaseOnProduction() {
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    assertEquals "v0.1.0-alpha.2" "$(version)"
    git checkout staging > /dev/null 2>&1
    assertEquals "v0.0.0-beta" "$(version)"
    git merge master --no-ff --no-edit > /dev/null
    assertEquals "v0.1.0-beta" "$(version)"
    git checkout production > /dev/null 2>&1
    assertEquals "v0.0.0" "$(version)"
    git merge staging --no-ff --no-edit > /dev/null
    assertEquals "v0.1.0" "$(version)"
    git checkout master > /dev/null 2>&1
    assertEquals "v0.2.0-alpha.0" "$(version)"
    git commit --allow-empty -m SimpleCommit2 > /dev/null
    assertEquals "v0.2.0-alpha.1" "$(version)"
}

testMajorReleaseOnProduction() {
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    assertEquals "v0.1.0-alpha.2" "$(version)"
    git checkout staging > /dev/null 2>&1
    assertEquals "v0.0.0-beta" "$(version)"
    git merge master --no-ff --no-edit -m "Merge branch 'master' into 'staging'" -m "+semver: major" > /dev/null
    assertEquals "v1.0.0-beta" "$(version)"
    git checkout production > /dev/null 2>&1
    assertEquals "v0.0.0" "$(version)"
    git merge staging --no-ff --no-edit > /dev/null
    assertEquals "v1.0.0" "$(version)"
    git checkout master > /dev/null 2>&1
    assertEquals "v1.1.0-alpha.0" "$(version)"
    git commit --allow-empty -m SimpleCommit2 > /dev/null
    assertEquals "v1.1.0-alpha.1" "$(version)"
}

testHotfixOnStage() {
    local hotfix_commit
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    git checkout staging > /dev/null 2>&1
    git merge master --no-ff --no-edit > /dev/null
    assertEquals "v0.1.0-beta" "$(version)"
    git checkout master > /dev/null 2>&1
    assertEquals "v0.2.0-alpha.0" "$(version)"
    git commit --allow-empty -m HotfixCommit1 > /dev/null
    assertEquals "v0.2.0-alpha.1" "$(version)"
    hotfix_commit=$(git log -1 --pretty=format:%h)
    git checkout staging > /dev/null 2>&1
    git cherry-pick "$hotfix_commit" --allow-empty --no-edit > /dev/null
    assertEquals "v0.1.1-beta" "$(version)"
}

testHotfixOnProduction() {
    local hotfix_commit
    git commit --allow-empty -m SimpleCommit1 > /dev/null
    git checkout staging > /dev/null 2>&1
    git merge master --no-ff --no-edit > /dev/null
    git checkout production > /dev/null 2>&1
    git merge staging --no-ff --no-edit > /dev/null
    assertEquals "v0.1.0" "$(version)"
    git checkout master > /dev/null 2>&1
    assertEquals "v0.2.0-alpha.0" "$(version)"
    git commit --allow-empty -m HotfixCommit1 > /dev/null
    assertEquals "v0.2.0-alpha.1" "$(version)"
    hotfix_commit=$(git log -1 --pretty=format:%h)
    git checkout staging > /dev/null 2>&1
    git cherry-pick "$hotfix_commit" --allow-empty --no-edit > /dev/null
    assertEquals "v0.1.1-beta" "$(version)"
    git checkout production > /dev/null 2>&1
    git merge staging --no-ff --no-edit > /dev/null
    assertEquals "v0.1.1" "$(version)"
}

export SHUNIT_PARENT
SHUNIT_PARENT=$(readlink -f "$0")
# shellcheck disable=SC1091
. "./shunit2"