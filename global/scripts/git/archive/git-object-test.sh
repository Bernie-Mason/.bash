#!/bin/bash
#
# Depends on git-repository-stats

# Color variables
NC='\033[0m'              # Text Reset
Red='\033[0;31m'
Green='\033[0;32m'
Yellow='\033[0;33m'
UWhite='\033[4;37m'
Orange='\033[0;33m'

# Function to display help message
help() {
  echo "This purpose of this script is to demonstrate how adding different types
of files to a git repository impacts the repository size.

This script will create a git repository and allow you to add plain text files and binary
files to the repository. You can then modify the files and see how the repository size
changes. You can also view the repository statistics to see how the files are stored. 

git performs two operations to store files efficiently: compression and packing.
When a file is added to the repository, git compresses it using zlib \(DEFLATE\) 
and stores it in .git/objects. If the file is modified and the changes committed
the git stores the modified file in a new object. When a git gc is run the file
objects are packed into pack files and any objects that can be diffed (like plain 
text files) are stored as deltas. The index file describes the contents of the pack
file and is used to quickly access the objects. So creating objects compresses them
and packing the objects saves space by storing revisions as deltas.

How well these operations work depends on the type of file being added. Plain text
files can be compressed well and stored as deltas, while binary files may not be 
stored as deltas. Higher entrophy (more random) files are compressed less efficiently. 
Packing depends on the ability of git to diff the file to store them as deltas. 
Therefore adding a large high-entropy binary file to a git repository could be a bad idea 
as it does not compress well and it doesn't pack efficiently. If the file is regularly 
modified it will increase the size of the .git directory proportionally to its direct 
size and entropy.

The file operations in this script are designed to demonstrate this behavior. 
"
}

record_sizes() {
  if [ ! -f "$1" ]; then
    echo -e "${Red}Run, Git Objects Size, Binary file size, Git Objects File Count${NC}" > "$1"
  fi
  GIT_OBJECTS_SIZE=$(du -sh .git/objects | cut -f1)
  GIT_OBJECTS_FILE_COUNT=$(find .git/objects -type f ! -path ".git/objects/info/*" ! -path ".git/objects/pack/*" | wc -l)
  if [ -f binary_file.gz ]; then
    ARCHIVE_SIZE=$(du -sh binary_file.gz | cut -f1) 
  else
    ARCHIVE_SIZE="N/A"
  fi
  echo -e "${Orange}$2, $GIT_OBJECTS_SIZE, $ARCHIVE_SIZE, $GIT_OBJECTS_FILE_COUNT${NC}" >> "$1"
}

add_plain_text_files() {
  read -p $'\e[32mEnter the number of files to add (n): \e[0m' n
  read -p $'\e[32mEnter the size of each file in KB (m): \e[0m' m
  for i in $(seq 1 $n); do
    # dd if=/dev/zero of=file_$i.txt bs=1K count=$m > /dev/null 2>&1
    curl "https://github.com/MicrosoftEdge/WebView2Samples/blob/main/SampleApps/WebView2WpfBrowser/MainWindow.xaml" | head -c ${m}K > file_$i.html
  done
  git add ./*.html
  git commit -m "Added $n plain text files of size ${m}KB each" &> /dev/null
  record_sizes "$OUTPUT_FILE" "Added $n plain text files"
}

add_binary_file() {
  read -p "Enter the size of the binary file in KB (m): " m
  dd if=/dev/urandom of=binary_file bs=${m}K count=1 > /dev/null 2>&1
  gzip binary_file
  git add binary_file.gz
  git commit -m "Added a binary file of size ${m}KB" &> /dev/null
  record_sizes "$OUTPUT_FILE" "Added a binary file"
}

modify_plain_text_file() {
  files=($(find . -type f -name "*.html"))
  echo -e "${Yellow}Select a file to modify:${NC}"
  select file in "${files[@]}"; do
    if [[ -n "$file" ]]; then
      read -p $'\e[32mEnter the number of times to modify the file (n): \e[0m' n
      for i in $(seq 1 $n); do
        echo "Modification $i" >> "$file"
        git add "$file"
        git commit -m "Modified $file $i times" &> /dev/null
        record_sizes "$OUTPUT_FILE" "Modified $file $i times"
      done
      break
    else
      echo "Invalid selection. Please try again."
    fi
  done
}

modify_binary_file() {
  files=($(find . -type f -name "*.gz"))
  echo -e "${Yellow}Select a binary file to modify:${NC}"
  select file in "${files[@]}"; do
    if [[ -n "$file" ]]; then
      read -p $'\e[32mEnter the number of times to modify the file (n): \e[0m' n
      for i in $(seq 1 $n); do
        gzip -d "$file"
        file_name_without_gz="${file%.gz}"
        dd if=/dev/urandom bs=1K count=1 >> "$file_name_without_gz"
        gzip "$file_name_without_gz"
        git add "$file"
        git commit -m "Modified $file $i times" &> /dev/null
        record_sizes "$OUTPUT_FILE" "Modified $file $i times"
      done
      break
    else
      echo "Invalid selection. Please try again."
    fi
  done
}

show_session_stats(){
      column -s, -t < "$OUTPUT_FILE"
      read -p "Press any key to continue" _  # Wait for user input
}

run_git_gc() {
  git gc
  record_sizes "$OUTPUT_FILE" "After git gc"
}

rebuild_repo(){    
  rm "$OUTPUT_FILE"
  rm -rf "$DIRECTORY"
  mkdir -p "$DIRECTORY"
  cd "$DIRECTORY" || exit

  git init

  git commit -m "Initial commit" --allow-empty &> /dev/null
  record_sizes "$OUTPUT_FILE" "Empty repo"
}

# Main script
DIRECTORY="git_tests"
CURRENT_DIRECTORY=$(pwd)
OUTPUT_FILE="${CURRENT_DIRECTORY}/results.csv"
if [ ! -f "$OUTPUT_FILE" ]; then
  echo -e "${Red}Iteration, .git Size, .git/objects Size, Archive Size, objects count${NC}" > "$OUTPUT_FILE"
fi

if [ -d "$DIRECTORY" ]; then
  read -p $'\e[32mDirectory $DIRECTORY already exists. Do you want to clean the contents and start over? (y/n): \e[0m' choice
  case "$choice" in
    y|Y|yes|Yes)
      rebuild_repo
      ;;
    *)
      echo "Continuing with existing directory."
      cd "$DIRECTORY" || exit
      ;;
  esac
fi

clear
while true; do
  echo -e "${Blue}git object test script${NC}:"
  echo -e ""
  echo -e "${Yellow}Git options:"
  echo -e "\trs => Repository statistics"
  echo -e "\tss => Session statistics"
  echo -e "\tgc => Run GC"
  echo ""
  echo -e "File operations:"
  echo -e "\tap => Add plain text files (low entropy diffable file)"
  echo -e "\tab => Add a binary file (high entropy undiffable file and zip it)"
  echo -e "\tmp => Modify a plain text file"
  echo -e "\tmb => Modify a binary file"
  echo ""
  echo -e "Other options:"
  echo -e "\trr => Restart (rebuild repo)"
  echo -e "\thp => Help"
  echo -e "\tq  => Exit${NC}"
  echo ""
  read -p $'\e[32mEnter your choice: \e[0m' choice
  echo ""

  case "$choice" in
    rs)
      clear
      git-repository-stats
      ;;
    ss)
      show_session_stats
      read -p "Press any key to continue" _  # Wait for user input
      ;;
    gc)
      run_git_gc
      ;;
    ap)
      add_plain_text_files
      ;;
    ab)
      add_binary_file
      ;;
    mp)
      modify_plain_text_file
      ;;
    mb)
      modify_binary_file
      ;;
    rr)
      rebuild_repo
      ;;
    hp)
      help
      read -p "Press any key to continue" _  # Wait for user input
      ;;
    q)
      echo "Goodbye and good luck friend."
      exit 0
      ;;
    *)
      echo "Invalid choice. Please try again."
      read -p "Press any key to continue" _  # Wait for user input
      ;;
  esac
  clear
done