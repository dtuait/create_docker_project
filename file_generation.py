# file_generation.py

import os

def create_file(path, content):
    """Helper to write string content to a file."""
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

def generate_files(project_path: str, project_name: str):
    """
    Generate Docker/DevContainer files, plus an 'app-main' folder with helloworld.py
    """

    # 1) .devcontainer folder
    devcontainer_path = os.path.join(project_path, ".devcontainer")
    os.makedirs(devcontainer_path, exist_ok=True)

    # 2) figure out UID/GID. If on Windows, fallback to 1000/1000.
    #    If on WSL or Linux and it returns 0, fallback to 1000/1000 to avoid groupadd -g 0 issues
    if os.name == 'nt':
        current_uid = 1000
        current_gid = 1000
    else:
        uid = os.getuid()
        gid = os.getgid()
        # fallback if it's 0
        current_uid = uid if uid != 0 else 1000
        current_gid = gid if gid != 0 else 1000

    # 3) Dockerfile content
    #    We'll create a non-root user with CURRENT_UID/CURRENT_GID inside the container
    dockerfile_content = f"""# Use Python as base
# Use Python as base
FROM python:3.10-bullseye

# Build args for your local user
ARG CURRENT_UID=1000
ARG CURRENT_GID=1000

# Create group/user in container
RUN if [ "$CURRENT_UID" = "0" ] || [ "$CURRENT_GID" = "0" ]; then \\
      echo "Detected root UID/GID => fallback to UID=1000, GID=1000"; \\
      groupadd -g 1000 appuser && useradd -u 1000 -g 1000 -m appuser; \\
    else \\
      echo "Creating user with UID=$CURRENT_UID, GID=$CURRENT_GID"; \\
      groupadd -g $CURRENT_GID appuser && useradd -u $CURRENT_UID -g $CURRENT_GID -m appuser; \\
    fi

RUN apt-get update \\
    && apt-get install -y sudo locales \\
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \\
    && dpkg-reconfigure --frontend=noninteractive locales \\
    && update-locale LC_ALL=en_US.UTF-8 \\
    && apt-get clean \\
    && rm -rf /var/lib/apt/lists/*

# Give passwordless sudo if desired
RUN echo "appuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/appuser

# **Key**: make sure the user has a bash shell
RUN usermod --shell /bin/bash appuser

# Optionally set environment variables for your shell
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

# Create and install in a virtual environment
RUN mkdir -p /usr/src/venvs \\
    && python -m venv /usr/src/venvs/app-main
COPY requirements.txt /usr/src/
RUN /usr/src/venvs/app-main/bin/pip install --upgrade pip \\
    && /usr/src/venvs/app-main/bin/pip install -r /usr/src/requirements.txt

# Switch to the non-root user
USER appuser
WORKDIR /usr/src/project

# **Key**: default command is /bin/bash
CMD ["/bin/bash"]

"""
    create_file(os.path.join(devcontainer_path, "Dockerfile"), dockerfile_content)

    # 4) docker-compose.yaml
    docker_compose_content = f"""services:
  {project_name}-app-main:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        CURRENT_UID: ${{CURRENT_UID}}
        CURRENT_GID: ${{CURRENT_GID}}
    user: "${{CURRENT_UID}}:${{CURRENT_GID}}"
    command: sleep infinity
    stdin_open: true
    tty: true
    volumes:
      - ..:/usr/src/project
    environment:
      - GIT_USER_NAME
      - GIT_USER_EMAIL
      - CURRENT_UID
      - CURRENT_GID
"""
    create_file(os.path.join(devcontainer_path, "docker-compose.yaml"), docker_compose_content)

    # 5) .env
    env_content = f"""# .env for docker-compose
CURRENT_UID={current_uid}
CURRENT_GID={current_gid}
GIT_USER_NAME=Victor Reipur
GIT_USER_EMAIL=victor@reipur.com
"""
    create_file(os.path.join(devcontainer_path, ".env"), env_content)

    # 6) devcontainer.json
    devcontainer_json_content = f"""{{
    "name": "Dev container: {project_name}",
    "dockerComposeFile": "docker-compose.yaml",
    "service": "{project_name}-app-main",
    "workspaceFolder": "/usr/src/project",
    "remoteUser": "appuser",
    "customizations": {{
        "vscode": {{
            "settings": {{
                "python.defaultInterpreterPath": "/usr/src/venvs/app-main/bin/python"
            }},
            "extensions": [
                "ms-python.vscode-pylance",
                "ms-python.debugpy",
                "ms-python.python"
            ]
        }}
    }},
    "postStartCommand": "bash .devcontainer/postStartCommand.sh"
}}
"""
    create_file(os.path.join(devcontainer_path, "devcontainer.json"), devcontainer_json_content)

    # 7) postStartCommand.sh (optional)
    post_start_cmd = """#!/bin/bash
echo "Running postStartCommand.sh..."
"""
    create_file(os.path.join(devcontainer_path, "postStartCommand.sh"), post_start_cmd)

    # 8) requirements.txt (inside .devcontainer)
    requirements_txt = """# Add your Python dependencies here
"""
    create_file(os.path.join(devcontainer_path, "requirements.txt"), requirements_txt)

    # 9) .gitignore (optional, no Git references though)
    gitignore_content = """# Byte-compiled / optimized / DLL files
*.env
*.old
*.log
*.bak
.bashrc
.ssh/
.vscode-server/
.gitconfig
.cache/
.gnupg/
.bash_history
.dotnet/
"""
    create_file(os.path.join(project_path, ".gitignore"), gitignore_content)

    # 10) .vscode/launch.json
    vscode_path = os.path.join(project_path, ".vscode")
    os.makedirs(vscode_path, exist_ok=True)
    launch_json = r"""{
    "configurations": [
        {
            "name": "Python: Current File",
            "type": "debugpy",
            "request": "launch",
            "program": "${file}",
            "console": "integratedTerminal"
        }
    ]
}
"""
    create_file(os.path.join(vscode_path, "launch.json"), launch_json)

    # 11) app-main folder with helloworld.py
    app_main_path = os.path.join(project_path, "app-main")
    os.makedirs(app_main_path, exist_ok=True)
    hello_world = """def main():
    print("Hello from helloworld.py inside app-main folder!")

if __name__ == "__main__":
    main()
"""
    create_file(os.path.join(app_main_path, "helloworld.py"), hello_world)

    print(f"Files generated in: {project_path}")

