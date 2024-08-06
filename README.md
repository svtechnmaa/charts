## SVTECH_Public_Helmchart repo
This repo contains all subchart (grafana, icinga2, rundeck, etc) those are used in any [stack solution](https://github.com/moophat/SVTECH_Projects_Container/tree/master/kubernetes) at SVTECH (nmaa, elk, tacgui, etc).

This repo is also be linked to (artifacthub.io) so that all subchart are public on internet.

---
### Repo structure

[kubernetes](/kubernetes/README.md) - List of all subchart helm

[artifacthub](/artifacthub/README.md) - Package version of all subchart helm

---
### User guides:
This part will describe usecases and the process to commit new code on this repo (Note: [This](https://github.com/moophat/SVTECH_Projects_Container/tree/master/kubernetes) is where stack helmchart is saved)

#### Usecase 1: Add code to existing subchart
In this case, you just add code to existing subchart, commit it to github, wait for CI/CD finish integration test, you can see the build status after CI/CD finish

Remember to add prefix <i>fix</i> or <i>feat</i> before commit message when commiting to github

#### Usecase 2: Add new subchart
Add new subchart into [kubernetes](/kubernetes/README.md), then merge code into main branch.

Wait for CI/CD finish its build, new subchart will be push to [artifacthub](/artifacthub/README.md) folder and then it will be public on (artifacthub.io)

#### Usecase 3: Add new persistent volume to a subchart
Follow this [document](/docs/pv.md) to add a new persistent volume to a subchart

