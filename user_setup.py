# user_setup.py

import os
import subprocess

def setup_dockeruser(project_path: str, project_name: str):
    # 1) Create group if it does not exist
    # 2) Create or update user
    # 3) Change ownership of the project directory
    try:
        # groupadd -g 65000 dockeruser
        subprocess.run(["groupadd", "-g", "65000", "dockeruser"], check=False)
    except Exception:
        pass

    try:
        # useradd -u 65000 -g 65000 -m dockeruser
        subprocess.run(["id", "-u", "dockeruser"], check=True)
    except subprocess.CalledProcessError:
        subprocess.run(["useradd", "-u", "65000", "-g", "65000", "-m", "dockeruser"], check=False)

    print(f"Changing ownership and permissions of {project_name}...")
    subprocess.run(["chown", "dockeruser:dockeruser", project_path, "-R"], check=False)
    subprocess.run(["chmod", "770", project_path, "-R"], check=False)
