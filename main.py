# main.py

import sys
from parse_args import parse_arguments
from validations import validate_project_name
from directory_ops import create_or_overwrite_project_dir
from file_generation import generate_files

def main():
    args = parse_arguments()
    project_name = args.projectname
    overwrite = args.overwrite_existing_project

    # 1) Validate project name
    validate_project_name(project_name)

    # 2) Create or overwrite the project directory
    project_path = create_or_overwrite_project_dir(project_name, overwrite, base_path="..")

    # 3) Generate all DevContainer + Docker files, plus helloworld
    generate_files(project_path, project_name)

    print(f"Project '{project_name}' set up in: {project_path}")
    print("Done.")

if __name__ == "__main__":
    sys.exit(main())
