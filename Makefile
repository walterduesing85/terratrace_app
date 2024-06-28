# Makefile for pushing project to GitHub

# Define variables
GITHUB_REPO = git@github.com:walterduesing85/terratrace_app.git
COMMIT_MESSAGE = "Updated project"
BRANCH = main

.PHONY: init
init:
	@echo "Initializing repository..."
	@git init
	@git remote add origin $(GITHUB_REPO)

.PHONY: add
add:
	@echo "Adding all changes..."
	@git add .

.PHONY: commit
commit:
	@echo "Committing changes..."
	@git diff-index --quiet HEAD || git commit -m "$(COMMIT_MESSAGE)"

.PHONY: push
push:
	@echo "Pushing to repository..."
	@git push -u origin $(BRANCH)

.PHONY: all
all: add commit push
	@echo "All changes have been pushed to the repository."

.PHONY: setup
setup: init
	@echo "Repository initialized and remote set to $(GITHUB_REPO)"

.PHONY: status
status:
	@git status

.PHONY: log
log:
	@git log --oneline

.PHONY: pull
pull:
	@git pull origin $(BRANCH)
