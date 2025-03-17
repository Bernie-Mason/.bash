import requests
import os
import subprocess
import csv

# URL to fetch the list of projects
PROJECTS_URL = "https://bitbucket.thinksmartbox.com/rest/api/latest/projects"
AUTH_HEADER = {
    'Authorization': 'Basic YmVybmllOkl6WjAzYkRNMkRlWjhrRDdqSWNFN2p5VGU4SzEyQlVx'
}

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

def get_directory_size(path):
    total_size = 0
    for dirpath, dirnames, filenames in os.walk(path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            total_size += os.path.getsize(fp)
    return total_size

def clone_repo(repo_name, ssh_url, clone_root, csv_writer):
    repo_path = os.path.join(clone_root, repo_name)
    if not os.path.exists(repo_path):
        print(f"Cloning {repo_name} into {repo_path}...")
        subprocess.run(["git", "clone", ssh_url, repo_path])
    else:
        print(f"Repository {repo_name} already exists at {repo_path}")
        
    total_size = get_directory_size(repo_path)
    git_dir_size = get_directory_size(os.path.join(repo_path, '.git'))
    working_dir_size = total_size - git_dir_size

    print(f"Total size of {repo_name}: {total_size} bytes")
    print(f".git directory size of {repo_name}: {git_dir_size} bytes")
    print(f"Working directory size of {repo_name}: {working_dir_size} bytes")

    csv_writer.writerow([repo_name, total_size, git_dir_size, working_dir_size])

def main():
    clone_root = "C:\\dev\\repos_test"
    if not os.path.exists(clone_root):
        os.makedirs(clone_root)

    project_keys = fetch_projects()
    with open('repo_sizes.csv', mode='w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(["Repository Name", "Total Size (bytes)", ".git Directory Size (bytes)", "Working Directory Size (bytes)"])
        
        for project_key in project_keys:
            print(f"Fetching repositories for project {project_key}...")
            repos = fetch_repos(project_key)
            for repo in repos:
                repo_name = repo['name']
                ssh_url = next(link['href'] for link in repo['links']['clone'] if link['name'] == 'ssh')
                print(f"Cloning {repo_name} from {ssh_url}...")
                clone_repo(repo_name, ssh_url, clone_root, writer)

if __name__ == "__main__":
    main()