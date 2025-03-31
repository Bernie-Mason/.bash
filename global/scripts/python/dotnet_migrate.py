import os
import shutil
import xml.etree.ElementTree as ET
import requests

def find_csproj_files(directory):
    """Recursively find all .csproj files in the given directory."""
    csproj_files = []
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".csproj"):
                csproj_files.append(os.path.join(root, file))
    return csproj_files

def backup_csproj_file(csproj_path):
    """Create a backup of the .csproj file."""
    backup_path = csproj_path + ".backup"
    shutil.copy(csproj_path, backup_path)
    print(f"Backup created: {backup_path}")

def update_csproj_file(csproj_path):
    """Update the .csproj file to use the latest .NET target framework."""
    tree = ET.parse(csproj_path)
    root = tree.getroot()

    # Update the TargetFramework to net9.0
    for property_group in root.findall("PropertyGroup"):
        target_framework = property_group.find("TargetFramework")
        if target_framework is not None:
            target_framework.text = "net9.0"
            print(f"Updated TargetFramework to net9.0 in {csproj_path}")

    # Save the updated .csproj file
    tree.write(csproj_path, encoding="utf-8", xml_declaration=True)

def get_package_upgrade_options(package_name):
    """Fetch the latest version of a NuGet package."""
    url = f"https://api.nuget.org/v3-flatcontainer/{package_name}/index.json"
    response = requests.get(url)
    if response.status_code == 200:
        versions = response.json().get("versions", [])
        if versions:
            return versions[-1]  # Return the latest version
    return None

def update_packages(csproj_path):
    """Check and suggest updates for NuGet packages in the .csproj file."""
    tree = ET.parse(csproj_path)
    root = tree.getroot()

    for item_group in root.findall("ItemGroup"):
        for package in item_group.findall("PackageReference"):
            package_name = package.attrib.get("Include")
            current_version = package.attrib.get("Version")
            if package_name and current_version:
                latest_version = get_package_upgrade_options(package_name)
                if latest_version and latest_version != current_version:
                    print(f"Package '{package_name}' has a newer version: {latest_version} (current: {current_version})")
                    choice = input(f"Do you want to update '{package_name}' to version {latest_version}? (y/n): ").strip().lower()
                    if choice == "y":
                        package.attrib["Version"] = latest_version
                        print(f"Updated '{package_name}' to version {latest_version}")

    # Save the updated .csproj file
    tree.write(csproj_path, encoding="utf-8", xml_declaration=True)

def main():
    print("Scanning for .csproj files...")
    csproj_files = find_csproj_files(os.getcwd())

    if not csproj_files:
        print("No .csproj files found in the current directory.")
        return

    print("Please select from the following .csproj files:")
    for i, csproj_file in enumerate(csproj_files, start=1):
        print(f"  {i}. {csproj_file}")

    choice = input("Enter the number of the project you want to migrate: ").strip()
    if not choice.isdigit() or int(choice) < 1 or int(choice) > len(csproj_files):
        print("Invalid choice.")
        return

    selected_csproj = csproj_files[int(choice) - 1]
    print(f"Selected project: {selected_csproj}")

    # Backup the .csproj file
    backup_csproj_file(selected_csproj)

    # Update the .csproj file
    update_csproj_file(selected_csproj)

    # Update NuGet packages
    update_packages(selected_csproj)

    print("Migration complete.")

if __name__ == "__main__":
    main()