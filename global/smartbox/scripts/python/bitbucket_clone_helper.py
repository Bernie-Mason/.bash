import requests
import os
import subprocess

AUTH_KEY = ""
PROJECTS_URL = "https://bitbucket.thinksmartbox.com/rest/api/latest/projects"
AUTH_HEADER = {
    'Authorization': f"Basic {AUTH_KEY}"
}

COLOR_BLUE_BOLD = "\033[1;34m"
COLOR_RED_BOLD = "\033[1;31m"
COLOR_YELLOW_BOLD = "\033[1;33m"
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
    print(f"Fetching repository list from {REPO_URL}...")
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
    while True:
        print(f"{COLOR_BLUE_BOLD}Project Menu:{COLOR_RESET}")
        for i, project_key in enumerate(project_keys):
            print(f"  {i + 1}. {project_key}")
        print("  q. Quit")

        choice = input("Select a project or quit: ").strip().lower()
        print(choice)
        clear_terminal()
        print("Terminal cleared")
        if choice == 'q':
            break
        elif choice.isdigit() and 1 <= int(choice) <= len(project_keys):
            print(f"Selected project: {project_keys[int(choice) - 1]}")
            project_key = project_keys[int(choice) - 1]
            repo_menu(project_key)
        else:
            print(f"{COLOR_RED_BOLD}Invalid choice. Please try again.{COLOR_RESET}\n")

def repo_menu(project_key):
    if not AUTH_KEY:
        print(f"{COLOR_RED_BOLD}Please set the AUTH_KEY variable to your Bitbucket password base64 encoded.{COLOR_RESET}")
    print("repo menu")
    clone_root = "C:\\dev"
    if not os.path.exists(clone_root):
        os.makedirs(clone_root)
    print("repo menu")

    clear_terminal()
    print("repo menu")

    repos = fetch_repos(project_key)
    while True:
        print(f"{COLOR_BLUE_BOLD}Repos in {project_key} projects (will clone to /c/dev):{COLOR_RESET}")
        for i, repo in enumerate(repos):
            print(f"  {i + 1}. {repo['name']}")
        print("  b. Back to project menu")
        print("  q. Quit")

        choice = input("Select a repository to clone, go back, or quit: ").strip().lower()
        clear_terminal()
        if choice == 'q':
            exit()
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