# directory_ops.py
import os
import shutil
import sys

def create_or_overwrite_project_dir(project_name: str, overwrite: bool, base_path=".."):
    project_path = os.path.join(base_path, project_name)
    
    if os.path.isdir(project_path):
        if overwrite:
            print(f"Overwriting existing project directory: {project_path}...")
            shutil.rmtree(project_path)
        else:
            print(f"Error: Directory '{project_name}' already exists. "
                  f"Use --overwrite-existing-project to overwrite it.")
            sys.exit(1)
    os.makedirs(project_path, exist_ok=True)
    return project_path
