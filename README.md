# Gitlab Merge Assistant

Gitlab provides a feature called [semi-linear history merge
requests](https://docs.gitlab.com/ee/user/project/merge_requests/#semi-linear-history-merge-requests)
which only allows fast forwardable merge. This ensures that the target
branch is always green.

If you have a mono repo or a repo with lot of committers, merging a
reviewed MR into master branch can get tedious. As only one MR can be
merged at a time and upon a merge, all the pending MRs will get
invalidated and should be rebased and tested again.

Assistant tries to automate the flow. Once a MR is reviewed, the
`Reviewed` label should be added by the reviewer. Assistant will
rebase and merge the reviewed MRs one by one.

Note: Gitlab has another feature called [Merge
Trains](https://docs.gitlab.com/ee/ci/merge_request_pipelines/pipelines_for_merged_results/merge_trains/)
which solves the same issue. You should use that if you have
enterprise subscription.

## Installation

The easiest way is to just run the latest [docker image](https://hub.docker.com/r/ananthakumaran/assistant) with the
required ENV variables.

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - env:
        - name: GITLAB_POLL_INTERVAL_SECONDS
          value: "30"
        - name: GITLAB_TOKEN
          value: xxxx
        - name: GITLAB_HOST
          value: https://gitlab.acme.com
        - name: GITLAB_PROJECTS
          value: group/project-a,group/sub-group/project-b
        image: ananthakumaran/assistant
        name: gitlab-assistant
```
