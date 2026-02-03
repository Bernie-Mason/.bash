#!/usr/bin/env python3
# filepath: c:\Users\BernardMason\.bash\global\smartbox\scripts\python\bitbucket_clone_helper.py
import requests
import os
import subprocess
import json

PROJECTS_URL = "https://bitbucket.thinksmartbox.com/rest/api/latest/projects"
AUTH_KEY_NAME = "bitBucketAuth"
COLOR_GREY = "\033[0;30m"
COLOR_WHITE = "\033[0;37m"
COLOR_BLUE_BOLD = "\033[1;34m"
COLOR_RED_BOLD = "\033[1;31m"
COLOR_YELLOW_BOLD = "\033[1;33m"
COLOR_YELLOW = "\033[0;33m"
COLOR_GREEN_BOLD = "\033[1;32m"
# Added new colors for menu variety
COLOR_CYAN = "\033[0;36m"
COLOR_CYAN_BOLD = "\033[1;36m"
COLOR_MAGENTA = "\033[0;35m"
COLOR_MAGENTA_BOLD = "\033[1;35m"
COLOR_GREEN = "\033[0;32m"
COLOR_BLUE = "\033[0;34m"
COLOR_RESET = "\033[0m"

def fetch_projects(auth_header):
    print(f"Fetching project list from {PROJECTS_URL}...")
    response = requests.get(PROJECTS_URL, headers=auth_header)
    if response.status_code == 200:
        projects = response.json().get('values', [])
        project_keys = [project['key'] for project in projects]
        return project_keys
    else:
        print(f"{COLOR_RED_BOLD}Failed to fetch projects. Status code: {response.status_code}{COLOR_RESET}")
        print(f"{COLOR_RED_BOLD}Suggestion to check your authentication token.{COLOR_RESET}")
        return []

def fetch_repos(project_key, auth_header):
    REPO_URL = f"https://bitbucket.thinksmartbox.com/rest/api/latest/projects/{project_key}/repos"
    response = requests.get(REPO_URL, headers=auth_header)
    if response.status_code == 200:
        repos = response.json().get('values', [])
        return repos
    else:
        print(f"Failed to fetch repositories for project {project_key}. Status code: {response.status_code}")
        return []

def clear_terminal():
    os.system('cls' if os.name == 'nt' else 'clear') # Clear terminal for Windows and Unix-based systems

def project_menu(project_keys, auth_header):
    clear_terminal()
    clone_root = "C:\\dev"
    clone_protocol = "ssh"
    
    # Color palette for projects - cycles through different colors
    project_colors = [COLOR_CYAN, COLOR_GREEN, COLOR_MAGENTA, COLOR_BLUE, COLOR_YELLOW]
    
    while True:
        print(f"{COLOR_CYAN_BOLD}╔═══════════════════════════════════════════════════════════════╗{COLOR_RESET}")
        print(f"{COLOR_CYAN_BOLD}║                      {COLOR_WHITE}PROJECT MENU{COLOR_CYAN_BOLD}                           ║{COLOR_RESET}")
        print(f"{COLOR_CYAN_BOLD}╚═══════════════════════════════════════════════════════════════╝{COLOR_RESET}")
        print(f"{COLOR_WHITE}Clone Root: {COLOR_GREEN_BOLD}{clone_root}{COLOR_RESET}")
        print(f"{COLOR_WHITE}Protocol:   {COLOR_GREEN_BOLD}{clone_protocol.upper()}{COLOR_RESET}")
        print()
        print(f"{COLOR_MAGENTA_BOLD}📂 Available Projects:{COLOR_RESET}")
        
        for i, project_key in enumerate(project_keys):
            color = project_colors[i % len(project_colors)]
            print(f"{color}  {i + 1:2d}. {project_key}{COLOR_RESET}")
        
        print()
        print(f"{COLOR_BLUE_BOLD}⚙️  Configuration Options:{COLOR_RESET}")
        print(f"{COLOR_CYAN}  c.  Change clone root directory{COLOR_RESET}")
        print(f"{COLOR_CYAN}  p.  Change clone protocol (ssh/https){COLOR_RESET}")
        print()
        print(f"{COLOR_RED_BOLD}  q.  Quit{COLOR_RESET}")
        print()
        print(f"{COLOR_YELLOW_BOLD}═══════════════════════════════════════════════════════════════{COLOR_RESET}")

        choice = input(f"{COLOR_WHITE}Select a project to clone repositories from: {COLOR_RESET}").strip().lower()
        print(choice)
        clear_terminal()
        if choice == 'q':
            break
        if choice == 'p':
            new_protocol = input(f"{COLOR_CYAN}Enter new clone protocol (ssh/https) (current: {COLOR_GREEN_BOLD}{clone_protocol}{COLOR_RESET}): ").strip().lower()
            if new_protocol in ['ssh', 'https']:
                clone_protocol = new_protocol
                print(f"{COLOR_GREEN_BOLD}✓ Clone protocol updated to: {clone_protocol}{COLOR_RESET}")
            else:
                print(f"{COLOR_RED_BOLD}❌ Invalid protocol. Please enter 'ssh' or 'https'.{COLOR_RESET}\n")
        elif choice == 'c':
            new_clone_root = input(f"{COLOR_CYAN}Enter new clone root (current: {COLOR_GREEN_BOLD}{clone_root}{COLOR_RESET}): ").strip()
            if new_clone_root:
                clone_root = new_clone_root
                print(f"{COLOR_GREEN_BOLD}✓ Clone root updated to: {clone_root}{COLOR_RESET}")
        elif choice.isdigit() and 1 <= int(choice) <= len(project_keys):
            selected_project = project_keys[int(choice) - 1]
            print(f"{COLOR_GREEN_BOLD}✓ Selected project: {selected_project}{COLOR_RESET}")
            repo_menu(selected_project, clone_root, auth_header, clone_protocol)
        else:
            print(f"{COLOR_RED_BOLD}❌ Invalid choice. Please try again.{COLOR_RESET}\n")

def repo_menu(project_key, clone_root, auth_header, clone_protocol):
    if not os.path.exists(clone_root):
        os.makedirs(clone_root)
    clear_terminal()

    repos = fetch_repos(project_key, auth_header)
    repo_colors = [COLOR_GREEN, COLOR_CYAN, COLOR_MAGENTA, COLOR_YELLOW, COLOR_BLUE]
    
    while True:
        print(f"{COLOR_BLUE_BOLD}╔═══════════════════════════════════════════════════════════════╗{COLOR_RESET}")
        print(f"{COLOR_BLUE_BOLD}║               {COLOR_WHITE}REPOSITORIES IN {project_key}{COLOR_BLUE_BOLD}                ║{COLOR_RESET}")
        print(f"{COLOR_BLUE_BOLD}╚═══════════════════════════════════════════════════════════════╝{COLOR_RESET}")
        print(f"{COLOR_WHITE}Clone Location: {COLOR_GREEN_BOLD}{clone_root}{COLOR_RESET}")
        print()
        print(f"{COLOR_MAGENTA_BOLD}📦 Available Repositories:{COLOR_RESET}")
        
        for i, repo in enumerate(repos):
            color = repo_colors[i % len(repo_colors)]
            print(f"{color}  {i + 1:2d}. {repo['name']}{COLOR_RESET}")
        
        print()
        print(f"{COLOR_BLUE_BOLD}🔙 Navigation:{COLOR_RESET}")
        print(f"{COLOR_CYAN}  b.  Back to project menu{COLOR_RESET}")
        print(f"{COLOR_RED_BOLD}  q.  Quit{COLOR_RESET}")
        print()
        print(f"{COLOR_YELLOW_BOLD}═══════════════════════════════════════════════════════════════{COLOR_RESET}")
        
        choice = input(f"{COLOR_WHITE}Select a repository to clone, go back, or quit: {COLOR_RESET}").strip().lower()
        clear_terminal()
        if choice == 'q':
            exit()
        elif choice == 'b':
            break
        elif choice.isdigit() and 1 <= int(choice) <= len(repos):
            repo = repos[int(choice) - 1]
            repo_name = repo['name']
            url = next(link['href'] for link in repo['links']['clone'] if link['name'] == 'ssh')

            if clone_protocol == 'https':
                url = next(link['href'] for link in repo['links']['clone'] if link['name'] == 'http')

            repo_path = os.path.join(clone_root, repo_name)
            if not os.path.exists(repo_path):
                print(f"{COLOR_BLUE_BOLD}🔄 Cloning {COLOR_CYAN_BOLD}{repo_name}{COLOR_RESET} from {COLOR_YELLOW}{url}{COLOR_RESET}")
                print(f"{COLOR_WHITE}📁 Target: {COLOR_GREEN}{repo_path}{COLOR_RESET}...")
                result = subprocess.run(["git", "clone", url, repo_path])
                if result.returncode == 0:
                    clear_terminal()
                    print(f"{COLOR_GREEN_BOLD}✅ Successfully cloned {repo_name}.{COLOR_RESET}\n")
                else:
                    print(f"{COLOR_RED_BOLD}❌ Failed to clone {repo_name}. Exit code: {result.returncode}{COLOR_RESET}\n")

                current_dir = os.getcwd()
                os.chdir(repo_path)
                print(f"{COLOR_YELLOW_BOLD}🔧 Do you want to turn on git maintenance for {COLOR_CYAN_BOLD}{repo_name}{COLOR_YELLOW_BOLD}? (y/n): {COLOR_RESET}")
                choice = input().strip().lower()
                if choice == 'y':
                    result = subprocess.run(["git", "maintenance", "start"])
                    if result.returncode == 0:
                        print(f"{COLOR_GREEN_BOLD}✅ Git maintenance enabled for {repo_name}.{COLOR_RESET}\n")
                    else:
                        print(f"{COLOR_RED_BOLD}❌ Failed to enable git maintenance for {repo_name}. Exit code: {result.returncode}{COLOR_RESET}\n")
                else:
                    print(f"{COLOR_YELLOW}⏭️  Skipped git maintenance for {repo_name}.{COLOR_RESET}\n")

                os.chdir(current_dir)
            
            else:
                print(f"{COLOR_YELLOW_BOLD}⚠️  Repository {COLOR_CYAN_BOLD}{repo_name}{COLOR_YELLOW_BOLD} already exists at {COLOR_GREEN}{repo_path}{COLOR_RESET}\n")

        else:
            print(f"{COLOR_RED_BOLD}❌ Invalid choice. Please try again.{COLOR_RESET}\n")

def set_auth_key():
    scriptPath = os.path.abspath(__file__)
    scriptDirectory = os.path.dirname(scriptPath)
    auth_file = os.path.join(scriptDirectory, "auth.json")
    if not os.path.exists(auth_file):
        with open(auth_file, 'w') as f:
            json.dump({AUTH_KEY_NAME: ""}, f, indent=4)
            print(f"{COLOR_YELLOW}Auth file not found. Created it next to the script: {auth_file}{COLOR_RESET}")
            print(f"{COLOR_YELLOW}Please set the bitBucketAuth variable in {auth_file} to a BitBucket bearer token.{COLOR_RESET}")
            print(f"{COLOR_YELLOW}You can generate a token from your Bitbucket account settings.{COLOR_RESET}")
            print(f"{COLOR_YELLOW}Open the file and set the value for {AUTH_KEY_NAME}.{COLOR_RESET}")
            print(f"{COLOR_YELLOW}Make sure to save the file after editing.{COLOR_RESET}")
            print(f"{COLOR_YELLOW}Then run the script again.{COLOR_RESET}")
            exit()
    
    with open(auth_file, 'r') as f:
        json_string = f.read()
        try:
            data = json.loads(json_string)
            # Access the AUTH_KEY_NAME value
            auth_key =  data.get(AUTH_KEY_NAME, "")
            if not auth_key:
                return None
            return {
        'Authorization': f"Bearer {auth_key}"
    }
        except IndexError:
            print(f"{COLOR_RED_BOLD}Invalid auth file format. Please check the auth.json file.{COLOR_RESET}")
            exit()

def main():
    auth_header = set_auth_key()
    if not auth_header:
        print(f"{COLOR_RED_BOLD}Please set the AUTH_KEY variable to your Bitbucket password base64 encoded.{COLOR_RESET}")
        exit()

    project_keys = fetch_projects(auth_header)
    project_menu(project_keys, auth_header)

if __name__ == "__main__":
    main()