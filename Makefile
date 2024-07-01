GITHUB_REPO = git@github.com:walterduesing85/terratrace_app.git
PROJECT_DIR = .

setup:
	@if [ -d ".git" ]; then \
		echo "Git repository already initialized."; \
	else \
		git init; \
	fi
	@if git remote | grep origin; then \
		echo "Remote 'origin' already exists."; \
	else \
		git remote add origin $(GITHUB_REPO); \
		echo "Remote 'origin' added."; \
	fi

add:
	@git add .

commit:
	@git commit -m "Initial commit"

push:
	@git push -u origin master

all: setup add commit push
