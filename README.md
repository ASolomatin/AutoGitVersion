# Automatic git-based versioning

## Install

Just copy and use `version.sh` script inside the git directory.

## Flow

This script works with flow based on [GitLab flow](https://docs.gitlab.com/ee/topics/gitlab_flow.html) with some restrictions.

The repository contains three main branches (*master*, *staging* and *production*) and may have feature branches.

- The *master* branch is main branch for current development; *master* branch can be merged **only** to *staging*; All feature branches can be started **only** from *master*.
- The *staging* branch contains currently testing code (beta) and can be deployed on stage; *staging* branch can be merged **only** to master; *staging* branch **can not** contain individual commits except cherry-picked hotfixes.
- The *production* branch contains final code versions and can be deployed on production; *production* branch **can not** be merged to other branches; *production* branch **can not** contain **any** individual commits.
- The feature branches starts, like usualy, from *master* and merges back to *master*.
- Hotfix occurs according to the following algorithm: first, fixes are commited into the *master*, then, for verification, using cherry-pick, they are duplicated into *staging*. After verification, the *staging* is merged into *production*. So, all the branches can sometimes different history but after release always has same code and always can be merged without conflicts except features.

Main idea of this flow is that the code always moving only in one direction from *master* through *staging* to *production* and never back.

## Restrictions

- All merges should be done using git **recursive** policy (`--no-ff` option). The exception is feature branches, which can be merged in any way. This is important because the fast forward strategy does not leave the merge commit as evidence of release.
- Rebase is outlaw. Rebase can totally broke history and we will have wrong version as result.
- All merge commits must contains standard commit message with specified source and target branch. Eg.: "Merge branch 'staging' into production". (Script supports few most popular merge message formats)
- The *production* and *staging* branches **can not** be merged back to *master* because this will broke commits sequence and current version will lose hotfix versioning part. (And maybe something else. This case was not well tested yet.)

## Major version increment

Major version can be incremented by adding special comment to commit message: `+semver: major`. This will work on *master* branch, feature branches and inside the merge commit from *master* to *staging*. In other cases this comment will be ignored. Major version increment works only **once** per release.

## Usage example

### No git repository

```bash
$ ./version.sh
HEAD is detached
```

### Init

```bash
$ git init && git add . && git commit -m Initial && git checkout -b staging && git checkout -b production && git checkout master
Initialized empty Git repository in /home/alex/Projects/DummyTests/DummyCILib/.git/
[master (root-commit) 95c83f3] Initial
 9 files changed, 2406 insertions(+)
 create mode 100644 .gitignore
 create mode 100644 .gitlab-ci.yml
 create mode 100644 .vscode/launch.json
 create mode 100644 .vscode/settings.json
 create mode 100644 CONTRIBUTING
 create mode 100644 USAGE.md
 create mode 100755 shunit2
 create mode 100755 tests.sh
 create mode 100755 version.sh
Switched to a new branch 'staging'
Switched to a new branch 'production'
Switched to branch 'master'

$ ./version.sh
v0.1.0-alpha.1
```

### Branches

```bash
$ git checkout staging
Switched to branch 'staging'

$ ./version.sh
v0.0.0-beta

$ git checkout production
Switched to branch 'production'

$ ./version.sh
v0.0.0
```

### Simple commit

```bash
$ git checkout master
Switched to branch 'master'

$ git commit --allow-empty -m SimpleCommit1
[master 38b49c3] SimpleCommit1

$ ./version.sh
v0.1.0-alpha.2
```

### Feature

```bash
$ git checkout -b feature/DummyFeature
Switched to a new branch 'feature/DummyFeature'

$ ./version.sh
v0.1.0-feature_DummyFeature.2

$ git commit --allow-empty -m FeatureCommit1
[feature/DummyFeature ff699aa] FeatureCommit1

$ ./version.sh
v0.1.0-feature_DummyFeature.3

$ git checkout master
Switched to branch 'master'

$ ./version.sh
v0.1.0-alpha.2

$ git commit --allow-empty -m SimpleCommit2
[master 8c40b1a] SimpleCommit2

$ ./version.sh
v0.1.0-alpha.3

$ git merge feature/DummyFeature --no-ff --no-edit
Already up to date!
Merge made by the 'recursive' strategy.

$ git branch -d feature/DummyFeature
Deleted branch feature/DummyFeature (was ff699aa).

$ ./version.sh
v0.1.0-alpha.5
```

### Major commit

```bash
$ git commit --allow-empty -m MajorCommit1 -m "+semver: major"
[master e2559be] MajorCommit1

$ ./version.sh
v1.0.0-alpha.0
```

### Release on stage

```bash
$ git checkout staging
Switched to branch 'staging'

$ ./version.sh
v0.0.0-beta

$ git merge master --no-ff --no-edit
Already up to date!
Merge made by the 'recursive' strategy.

$ ./version.sh
v1.0.0-beta

$ git checkout master
Switched to branch 'master'

$ ./version.sh
v1.1.0-alpha.0
```

### Hotfix on stage

```bash
$ git commit --allow-empty -m SimpleCommit3
[master d71b172] SimpleCommit3

$ ./version.sh
v1.1.0-alpha.1

$ git commit --allow-empty -m HotfixCommit1
[master 0f751dc] HotfixCommit1

$ ./version.sh
v1.1.0-alpha.2

$ git commit --allow-empty -m SimpleCommit4
[master d86c9d9] SimpleCommit4

$ ./version.sh
v1.1.0-alpha.3

$ git checkout staging
Switched to branch 'staging'

$ ./version.sh
v1.0.0-beta

$ git cherry-pick 0f751dc --allow-empty --no-edit
[staging 074ddfd] HotfixCommit1
 Date: Mon May 3 02:05:06 2021 +0300

$ ./version.sh
v1.0.1-beta
```

### Release on production

```bash
$ git checkout production
Switched to branch 'production'

$ ./version.sh
v0.0.0

$ git merge staging --no-ff --no-edit
Already up to date!
Merge made by the 'recursive' strategy.

$ ./version.sh
v1.0.1
```
























