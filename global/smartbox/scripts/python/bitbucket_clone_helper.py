import requests
import os
import subprocess

AUTH_KEY = ""
PROJECTS_URL = "https://bitbucket.thinksmartbox.com/rest/api/latest/projects"
AUTH_HEADER = {
    'Authorization': f"Basic {AUTH_KEY}"
}

COLOR_GREY = "\033[0;30m"
COLOR_WHITE = "\033[0;37m"
COLOR_BLUE_BOLD = "\033[1;34m"
COLOR_RED_BOLD = "\033[1;31m"
COLOR_YELLOW_BOLD = "\033[1;33m"
COLOR_YELLOW = "\033[0;33m"
COLOR_GREEN_BOLD = "\033[1;32m"
COLOR_RESET = "\033[0m"

def fetch_projects():
    print(f"Fetching project list from {PROJECTS_URL}...")
    response = requests.get(PROJECTS_URL, headers=AUTH_HEADER)
    if response.status_code == 200:
        projects = response.json().get('values', [])
        project_keys = [project['key'] for project in projects]
        return project_keys
    else:
        print(f"Failed to fetch projects. Status code: {response.status_code}")
        return []

def fetch_repos(project_key):
    REPO_URL = f"https://bitbucket.thinksmartbox.com/rest/api/latest/projects/{project_key}/repos"
    #print(f"{COLOR_GREY}Fetching repository list from {REPO_URL}...{COLOR_RESET}")
    response = requests.get(REPO_URL, headers=AUTH_HEADER)
    if response.status_code == 200:
        repos = response.json().get('values', [])
        return repos
    else:
        print(f"Failed to fetch repositories for project {project_key}. Status code: {response.status_code}")
        return []

def clear_terminal():
    os.system('cls' if os.name == 'nt' else 'clear')

def project_menu(project_keys):
    clear_terminal()
    clone_root = "C:\\dev"
    while True:
        print(f"{COLOR_BLUE_BOLD}\nProject Menu:{COLOR_RESET}")
        for i, project_key in enumerate(project_keys):
            print(f"{COLOR_YELLOW}  {i + 1}. {project_key}{COLOR_RESET}")
        print(f"{COLOR_WHITE}  c. change clone root{COLOR_RESET}")
        print(f"{COLOR_WHITE}  q. quit{COLOR_RESET}")
        print("")

        choice = input("Select a project to clone repositories from: ").strip().lower()
        print(choice)
        clear_terminal()
        if choice == 'q':
            break
        elif choice == 'c':
            new_clone_root = input(f"Enter new clone root (current: {clone_root}): ").strip()
            if new_clone_root:
                clone_root = new_clone_root
                print(f"Clone root updated to: {clone_root}")
        elif choice.isdigit() and 1 <= int(choice) <= len(project_keys):
            print(f"Selected project: {project_keys[int(choice) - 1]}")
            project_key = project_keys[int(choice) - 1]
            repo_menu(project_key, clone_root)
        else:
            print(f"{COLOR_RED_BOLD}Invalid choice. Please try again.{COLOR_RESET}\n")

def repo_menu(project_key, clone_root):
    if not AUTH_KEY:
        print(f"{COLOR_RED_BOLD}Please set the AUTH_KEY variable to your Bitbucket password base64 encoded.{COLOR_RESET}")
    if not os.path.exists(clone_root):
        os.makedirs(clone_root)

    clear_terminal()

    repos = fetch_repos(project_key)
    while True:
        print(f"\n{COLOR_BLUE_BOLD}Repos in {project_key} projects (will clone to {clone_root}):{COLOR_RESET}")
        for i, repo in enumerate(repos):
            print(f"{COLOR_YELLOW}  {i + 1}. {repo['name']}{COLOR_RESET}")
        print(f"{COLOR_WHITE}  b. Back to project menu{COLOR_RESET}")
        print(f"{COLOR_WHITE}  q. Quit{COLOR_RESET}\n")
        choice = input("Select a repository to clone, go back, or quit: ").strip().lower()
        clear_terminal()
        if choice == 'q':
            exit()
        elif choice == 'b':
            break
        elif choice == 'b':
            break
        elif choice.isdigit() and 1 <= int(choice) <= len(repos):
            repo = repos[int(choice) - 1]
            repo_name = repo['name']
            ssh_url = next(link['href'] for link in repo['links']['clone'] if link['name'] == 'ssh')
            repo_path = os.path.join(clone_root, repo_name)
            if not os.path.exists(repo_path):
                print(f"Cloning {repo_name} from {ssh_url} into {repo_path}...")
                result = subprocess.run(["git", "clone", ssh_url, repo_path])
                if result.returncode == 0:
                    clear_terminal()
                    print(f"{COLOR_GREEN_BOLD}Successfully cloned {repo_name}.{COLOR_RESET}\n")
                else:
                    print(f"{COLOR_RED_BOLD}Failed to clone {repo_name}. Exit code: {result.returncode}{COLOR_RESET}\n")
            
            else:
                print(f"{COLOR_YELLOW_BOLD}Repository {repo_name} already exists at {repo_path}{COLOR_RESET}\n")
        else:
            print(f"{COLOR_RED_BOLD}Invalid choice. Please try again.{COLOR_RESET}\n")

def main():
    project_keys = fetch_projects()
    project_menu(project_keys)

if __name__ == "__main__":
    main()