import requests
import os
import subprocess
import json
import sys
from enum import Enum

# --- CONFIGURATION ---
BITBUCKET_URL = "https://bitbucket.thinksmartbox.com"
API_BASE = f"{BITBUCKET_URL}/rest/api/latest"
PROJECT = "apps"
REPO = "GRID"
LIMIT = 1000
AUTH_KEY_NAME = "bitBucketAuth"
COLOR_GREY = "\033[0;30m"
COLOR_WHITE = "\033[0;37m"
COLOR_BLUE_BOLD = "\033[1;34m"
COLOR_RED_BOLD = "\033[1;31m"
COLOR_YELLOW_BOLD = "\033[1;33m"
COLOR_YELLOW = "\033[0;33m"
COLOR_GREEN_BOLD = "\033[1;32m"
COLOR_RESET = "\033[0m"
VERBOSE = '--verbose' in sys.argv

def extendPrArray(pr_array, data, pr_prefix):
    pr_array.extend(
        pr["id"]
        for pr in data["values"]
        if pr.get("fromRef", {}).get("displayId", "").startswith(pr_prefix)
    )

def get_merged_bugfix_pr_ids(auth_header):
    # Handle pages. The API returns a maximum of 1000 results per page.
    # If there are more than 1000 results, we need to paginate.
    # We can use the 'start' parameter to get the next page of results.
    start = 0
    url = (f"{API_BASE}/projects/{PROJECT}/repos/{REPO}/pull-requests"
           f"?limit={LIMIT}&withAttributes=false&withProperties=false"
           f"&state=MERGED&at=refs/heads/master")
    bugfix_ids = []
    feature_ids = []
    task_ids = []
    other_ids = []
    while True:
        if VERBOSE:
            print(f"{COLOR_YELLOW}Fetching next page of PRs from {start} to {start + LIMIT}...{COLOR_RESET}")
        next_url = f"{url}&start={start}"
        resp = requests.get(next_url, headers=auth_header)
        resp.raise_for_status()
        data = resp.json()
        if not data.get("values"):
            print(f"{COLOR_YELLOW} PRs found.{COLOR_RESET}")
            break

        extendPrArray(bugfix_ids, data, "bugfix")
        extendPrArray(feature_ids, data, "feature")
        extendPrArray(task_ids, data, "task")
        other_ids.extend(
            pr["id"]
            for pr in data["values"]
            if not (
                pr.get("fromRef", {}).get("displayId", "").startswith("bugfix") or
                pr.get("fromRef", {}).get("displayId", "").startswith("feature") or
                pr.get("fromRef", {}).get("displayId", "").startswith("task")
            )
        )
        start += LIMIT
    
    if VERBOSE:
        print(f"{COLOR_YELLOW}Found {len(feature_ids)} feature PRs.{COLOR_RESET}")
        print(f"{COLOR_YELLOW}Found {len(task_ids)} task PRs.{COLOR_RESET}")
        print(f"{COLOR_YELLOW}Found {len(other_ids)} other PRs.{COLOR_RESET}")
    return bugfix_ids

class PRStatus(Enum):
    DELETED = 1
    INCLUDES_TESTS = 2
    NO_TESTS = 3
    UNKNOWN = 4

def pr_includes_tests(pr_id, auth_header):
    url = (f"{API_BASE}/projects/{PROJECT}/repos/{REPO}/pull-requests/"
           f"{pr_id}/changes?limit=1000")

    resp = requests.get(url, headers=auth_header)
    if resp.status_code == 404:
        if VERBOSE:
            print(f"{COLOR_RED_BOLD}PR ID {pr_id} not found. It may have been deleted.{COLOR_RESET}")
        return PRStatus.DELETED
    data = resp.json()
    for change in data.get("values", []):
        parent = change.get("path", {}).get("parent", "")
        parts = parent.split("/")
        if len(parts) > 1 and ".Tests" in parts[1]:
            if VERBOSE:
                print(f"{COLOR_GREEN_BOLD}PR ID {pr_id} includes tests in the second directory: {parts[1]}{COLOR_RESET}")
            return PRStatus.INCLUDES_TESTS
    if any("Directory.Build.props" in change.get("path", {}).get("name", "") for change in data.get("values", [])):
        return PRStatus.UNKNOWN
    return PRStatus.NO_TESTS

def ensure_auth_key():
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
            auth_key =  data.get(AUTH_KEY_NAME, "")
            return {
        'Authorization': f"Bearer {auth_key}"
    }
        except IndexError:
            print(f"{COLOR_RED_BOLD}Invalid auth file format. Please check the auth.json file.{COLOR_RESET}")

def main():
    os.system('cls' if os.name == 'nt' else 'clear')

    print(f"{COLOR_BLUE_BOLD}This script will check all merged bugfix PRs in the {PROJECT} project of the {REPO} repository.{COLOR_RESET}")
    print(f"{COLOR_BLUE_BOLD}It will then inspect each modified file in the PR for the presence of the string '.Tests' in the second directory (the first directory is always Source).{COLOR_RESET}")

    print(f"{COLOR_GREEN_BOLD}Getting auth key...{COLOR_RESET}")
    auth_header = ensure_auth_key()
    if not auth_header:
        print(f"{COLOR_RED_BOLD}Please set the AUTH_KEY variable to your Bitbucket password base64 encoded.{COLOR_RESET}")
        exit()

    print(f"{COLOR_WHITE} -> Auth key obtained.{COLOR_RESET}")
    print(f"{COLOR_GREEN_BOLD}Fetching merged bugfix PRs...{COLOR_RESET}")
    bugfix_pr_ids = get_merged_bugfix_pr_ids(auth_header)
    if not bugfix_pr_ids:
        print(f"{COLOR_RED_BOLD}\r -> No bugfix PRs found.{COLOR_RESET}")
        return

    print(f"{COLOR_WHITE} -> Found {len(bugfix_pr_ids)} merged bugfix PRs.{COLOR_RESET}")
    print(f"{COLOR_GREEN_BOLD}Checking for 'tested' PRs...{COLOR_RESET}")
    with_tests = 0
    unknown = 0
    no_tests = 0
    deleted = 0
    for i, pr_id in enumerate(bugfix_pr_ids, start=1):
        print(f"{COLOR_WHITE}Checking PR {i} of {len(bugfix_pr_ids)}...{COLOR_RESET}", end="\r")
        status = pr_includes_tests(pr_id, auth_header)
        if status == PRStatus.INCLUDES_TESTS:
            with_tests += 1
        elif status == PRStatus.UNKNOWN:
            unknown += 1
        elif status == PRStatus.NO_TESTS:
            no_tests += 1
        elif status == PRStatus.DELETED:
            deleted += 1

    percent = (with_tests / len(bugfix_pr_ids)) * 100
    
    print(f"{COLOR_BLUE_BOLD}\n\nSummary:{COLOR_RESET}")
    if VERBOSE:
        print(f"{COLOR_YELLOW_BOLD}{with_tests}: With tests in second directory{COLOR_RESET}")
        print(f"{COLOR_YELLOW_BOLD}{unknown}: Unknown (directory.build.props present){COLOR_RESET}")
        print(f"{COLOR_YELLOW_BOLD}{no_tests}: No tests in second directory{COLOR_RESET}")
        print(f"{COLOR_YELLOW_BOLD}{deleted}: Deleted PRs{COLOR_RESET}")
    print(f"\n{with_tests} out of {len(bugfix_pr_ids)} bugfix PRs ({percent:.2f}%) include tests.")

if __name__ == "__main__":
    main()