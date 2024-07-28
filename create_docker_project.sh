#!/bin/bash

# Initialize variables
PROJECT_NAME=""
OVERWRITE_EXISTING_PROJECT=false

# Process command-line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --projectname)
            PROJECT_NAME="$2"
            shift # Skip the argument value
            ;;
        --overwrite-existing-project)
            OVERWRITE_EXISTING_PROJECT=true
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift # Move to the next key or value
done


# require sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Check if project name was provided
if [ -z "$PROJECT_NAME" ]; then
  echo "Error: No project name provided. Use --projectname to specify the project name."
  exit 1
fi

# Validate the project name
if [[ ! "$PROJECT_NAME" =~ ^[a-z]+[a-z0-9-]*[a-z0-9]$ ]]; then
  echo "Error: Project name must contain only lowercase letters a-z, digits 0-9, and dashes (-), and cannot start or end with a digit or a dash."
  exit 1
fi

# Check for existing project directory
if [ -d "$PROJECT_NAME" ]; then
    if [ "$OVERWRITE_EXISTING_PROJECT" = true ]; then
        echo "Overwriting existing project..."
        rm -rf "../$PROJECT_NAME"
    else
        echo "Error: Project directory '$PROJECT_NAME' already exists. Use --overwrite-existing-project to overwrite."
        exit 1
    fi
fi

# Create project structure
mkdir -p "../$PROJECT_NAME"
cd "../$PROJECT_NAME"

# Initialize git and add submodules
git init --initial-branch=main
git submodule add https://github.com/dtuait/.docker-image-builder.git .devcontainer/.docker-image-builder
git submodule add https://github.com/dtuait/.docker-migrate.git .devcontainer/.docker-migrate

# Create a simple Dockerfile
cat > .devcontainer/Dockerfile <<EOF
# Use an official Python runtime as a parent image
FROM python:3.10-bullseye

# Build the Docker image with build arguments
# docker build \\
#   --build-arg DOCKERUSER_UID=\$DOCKERUSER_UID \\
#   --build-arg DOCKERUSER_GID=\$DOCKERUSER_GID \\
#   --build-arg DOCKERUSER_NAME=\$DOCKERUSER_NAME \\
#   --build-arg DOCKERUSER_PASSWORD=\$DOCKERUSER_PASSWORD \\
#   -t my-docker-project .
# or use default values
# docker build -t my-docker-project .
ARG DOCKERUSER_UID=65000
ARG DOCKERUSER_GID=65000
ARG DOCKERUSER_NAME=dockeruser
ARG DOCKERUSER_PASSWORD=dockeruser

ENV DOCKERUSER_UID=\${DOCKERUSER_UID}
ENV DOCKERUSER_GID=\${DOCKERUSER_GID}
ENV DOCKERUSER_NAME=\${DOCKERUSER_NAME}
ENV DOCKERUSER_PASSWORD=\${DOCKERUSER_PASSWORD}

###### fix locales ######
# Install locales package
RUN apt-get update && \\
    apt-get install -y locales

# Generate the en_US.UTF-8 locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \\
    dpkg-reconfigure --frontend=noninteractive locales && \\
    update-locale LC_ALL=en_US.UTF-8

# Set environment variables for locale
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
###### fix locales ######

RUN mkdir -p /usr/src/venvs && python -m venv /usr/src/venvs/app-main
COPY requirements.txt /usr/src/
RUN /usr/src/venvs/app-main/bin/pip install --upgrade pip && \\
    /usr/src/venvs/app-main/bin/pip install -r /usr/src/requirements.txt

# install basic utils
RUN apt-get update && apt-get install -y iputils-ping tree bash sudo gosu && rm -rf /var/lib/apt/lists/*

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh


# Copy app.py file
COPY app.py /usr/src/app.py

# Set the working directory in the container
WORKDIR /usr/src/project

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Run app.py when the container launches
CMD ["/bin/bash"]
EOF


# Create a .devcontainer/.docker-image-builder-archive folder
mkdir -p .devcontainer/.docker-image-builder-archive
mkdir -p app-main
mkdir -p .vscode



# Creata a .gitignore file
cat > .gitignore <<EOF
# Byte-compiled / optimized / DLL files
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
EOF










# Create a .devcontainer/requirments.txt file
cat > .devcontainer/requirements.txt <<EOF
# Add your Python dependencies here
EOF


# Create a .env file
cat > .devcontainer/postStartCommand.sh <<EOF
#!/bin/bash
echo "running postStartCommand.sh"
EOF

# Create postCreateCommand.sh 
cat > .devcontainer/postCreateCommand.sh <<EOF
#!/bin/bash

# this script runs first time when container is created
echo "running postCreateCommand.sh"

# store current pwd into a variable
current_pwd=\$(pwd)
cd /usr/src/project

# Check if /usr/src/project/.git is a valid git repository
if [ -d "/usr/src/project/.git" ]; then
    # Set git to ignore file mode (permissions) changes in this repository
    git --git-dir=/usr/src/project/.git config core.fileMode false
else
    echo "Error: /usr/src/project/.git is not a valid git repository."
fi

# Set git to ignore file mode (permissions) changes globally for all repositories
git config --global core.fileMode false

echo "Enter your username:"
read username
case \$username in
    afos)
        git config --global user.email "afos@dtu.dk"
        git config --global user.name "Anders Fosgerau"
        ;;
    jaholm)
        git config --global user.email "jaholm@dtu.dk"
        git config --global user.name "Jakob Holm"
        ;;
    vicre)
        git config --global user.email "vicre@dtu.dk"
        git config --global user.name "Victor Reipur"
        ;;
    vicmrp)
        git config --global user.email "victor.reipur@gmail.com"
        git config --global user.name "Victor Reipur"
        ;;
    *)
        echo "Enter your email:"
        read email
        git config --global user.email "\$email"
        echo "Enter your name:"
        read name
        git config --global user.name "\$name"
        ;;
esac

# git config --global --add safe.directory /usr/src/project
# git config --global --add safe.directory /mnt/project
# git config --global --add safe.directory /usr/src/project/.devcontainer/.docker-migrate
# git config --global --add safe.directory /usr/src/project/.devcontainer/.docker-image-builder
git config pull.rebase true



# show current pip freeze
echo "Show current pip freeze into requirements.txt..."
echo "This is done so dependabot can taste the current environment."
/usr/src/venvs/app-main/bin/pip freeze > /usr/src/project/app-main/requirements.txt

echo "Getting git submodules"
git submodule init && git submodule update

# git init initial commit
echo "Initial commit"
git add .
git commit -m "Initial commit"

echo "Ending postCreateCommand.sh"

# restore the pwd
cd \$current_pwd
EOF





# Create a .env file
cat > .devcontainer/.env <<EOF
# Docker user UID and GID
DOCKERUSER_UID=65000
DOCKERUSER_GID=65000
DOCKERUSER_NAME=dockeruser
DOCKERUSER_PASSWORD=dockeruser
DOCKERUSER_HOME=/home/dockeruser
DOCKERUSER_SHELL=/bin/bash
EOF


# cat > .devcontaienr/.devcontainer.json <<EOF
cat > .devcontainer/devcontainer.json <<EOF
{
    "name": "Dev container: $PROJECT_NAME",
    "dockerComposeFile": "docker-compose.yaml",
    "service": "$PROJECT_NAME-app-main",
    "workspaceFolder": "/usr/src/project",
    "remoteUser": "dockeruser",
    "customizations": {
        "vscode": {
            "settings": {
                "python.defaultInterpreterPath": "/usr/src/venvs/app-main/bin/python"
            },
            "extensions": [
                "GitHub.copilot",
                "ms-python.vscode-pylance",
                "ms-python.debugpy",
                "ms-python.python",
                "stuart.unique-window-colors"
            ]
        }
    },
    // This command is executed after the container is created but before it is started for the first time. 
    // It's useful for setup tasks that only need to be run once after the container is initially created, such as installing software,
    // configuring settings, or performing initial setup tasks that don't need to be repeated on subsequent starts of the container.
    // This command will not run again on container restarts unless the container is fully recreated.
    "postCreateCommand": "bash .devcontainer/postCreateCommand.sh",
    // postStartCommand: This command is executed every time the container is started,
    // including the first time after it's created and any subsequent restarts. 
    // This is suitable for tasks that need to be run every time the container starts, such as setting environment variables, 
    // starting background services, or running scripts that prepare the environment for the development session.
    "postStartCommand": "bash .devcontainer/postStartCommand.sh"
}
EOF



# Create .devcontainer/entrypoint.sh
cat > .devcontainer/entrypoint.sh <<EOF
#!/bin/bash

# Ensure the script exits if any command fails
set -e

# Read environment variables for user configuration
DOCKERUSER_UID=\${DOCKERUSER_UID:-65000}
DOCKERUSER_GID=\${DOCKERUSER_GID:-65000}
DOCKERUSER_NAME=\${DOCKERUSER_NAME:-dockeruser}
DOCKERUSER_PASSWORD=\${DOCKERUSER_PASSWORD:-dockeruser}
DOCKERUSER_HOME=\${DOCKERUSER_HOME:-/home/dockeruser}
DOCKERUSER_SHELL=\${DOCKERUSER_SHELL:-/bin/bash}

# Function to setup or update home directory
setup_home_directory () {
    # Ensure the home directory exists and is owned correctly
    # echo "Setting up home directory \$1"
    mkdir -p \$1
    chown \$DOCKERUSER_UID:\$DOCKERUSER_GID \$1
    # Ensure basic configuration files are in place
    if [ ! -f "\$1/.bashrc" ]; then
        touch "\$1/.bashrc"
        chown \$DOCKERUSER_UID:\$DOCKERUSER_GID "\$1/.bashrc"
    fi
}

# Create group if it does not exist
if ! getent group \$DOCKERUSER_GID &>/dev/null; then
    groupadd -g \$DOCKERUSER_GID \$DOCKERUSER_NAME
fi

# Create or modify the user
if ! id -u \$DOCKERUSER_UID &>/dev/null; then
    # echo "Creating user \$DOCKERUSER_NAME with UID \$DOCKERUSER_UID and GID \$DOCKERUSER_GID"
    useradd -u \$DOCKERUSER_UID -g \$DOCKERUSER_GID -m -d \$DOCKERUSER_HOME -s \$DOCKERUSER_SHELL \$DOCKERUSER_NAME > /dev/null 2>&1
    setup_home_directory \$DOCKERUSER_HOME
else
    usermod -u \$DOCKERUSER_UID -g \$DOCKERUSER_GID -d \$DOCKERUSER_HOME -s \$DOCKERUSER_SHELL \$DOCKERUSER_NAME
    if [ "\$(grep \$DOCKERUSER_NAME /etc/passwd | cut -d: -f6)" != "\$DOCKERUSER_HOME" ]; then
        # echo "Home directory for \$DOCKERUSER_NAME changed to \$DOCKERUSER_HOME"
        # If home directory changed, move contents
        user_home_old=\$(grep \$DOCKERUSER_NAME /etc/passwd | cut -d: -f6)
        mv \$user_home_old/* \$DOCKERUSER_HOME/ 2>/dev/null || true
        mv \$user_home_old/.* \$DOCKERUSER_HOME/ 2>/dev/null || true
        rmdir \$user_home_old || true
    fi
    setup_home_directory \$DOCKERUSER_HOME
fi

# Set ownership to the user's home directory and create .bashrc if not exists
chown \$DOCKERUSER_UID:\$DOCKERUSER_GID \$DOCKERUSER_HOME
touch \$DOCKERUSER_HOME/.bashrc
chown \$DOCKERUSER_UID:\$DOCKERUSER_GID \$DOCKERUSER_HOME/.bashrc

# Add dockeruser and grant sudo privileges
echo "\$DOCKERUSER_NAME:\$DOCKERUSER_PASSWORD" | chpasswd
usermod -aG sudo \$DOCKERUSER_NAME
echo "\$DOCKERUSER_NAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/\$DOCKERUSER_NAME

# Run the specified user's shell with gosu to ensure the correct user environment
# exec gosu \$DOCKERUSER_NAME \$DOCKERUSER_SHELL
# gosu \$DOCKERUSER_NAME /bin/bash -c "\$@"
exec gosu \$DOCKERUSER_NAME "\$@"

EOF



# Create development docker-compose.yaml
cat > .devcontainer/docker-compose.yaml <<EOF
# run this to get into the terminal for testing
# docker compose run --service-ports --rm test-my-docker-project-app-main bash
services:
  $PROJECT_NAME-app-main:
    build:
      context: .
      dockerfile: Dockerfile
    user: "\${HOST_UID}:\${HOST_GID}"  # Set user to dockeruser
    command: sleep infinity
    stdin_open: true  # Keep stdin open to allow interactive commands
    tty: true  # Allocate a pseudo-TTY for the container
    volumes:
      - ..:/usr/src/project
    environment:
      - HOST_UID=\${DOCKERUSER_UID}
      - HOST_GID=\${DOCKERUSER_GID}
      - DOCKERUSER_NAME=\${DOCKERUSER_NAME}
      - DOCKERUSER_PASSWORD=\${DOCKERUSER_PASSWORD}
      - DOCKERUSER_HOME=\${DOCKERUSER_HOME}
      - DOCKERUSER_SHELL=\${DOCKERUSER_SHELL}
EOF



cat > app-main/debug-test.py <<EOF
print("Hello, World!")
EOF

cat > .vscode/launch.json <<EOF
{
    "configurations": [
        {
            "name": "Python: Current File",
            "type": "debugpy",
            "request": "launch",
            "program": "\${file}",
            "console": "integratedTerminal"
        },
        {
            "name": "Python: Debug test",
            "type": "debugpy",
            "request": "launch",
            "program": "\${workspaceFolder}/app-main/debug-test.py",
            "console": "integratedTerminal",
            "django": true,
            "justMyCode": true
        }
]
}
EOF






# Create a folder called app-main and create a file called app.py
cat > .devcontainer/app.py <<EOF
print("Hello, World!")
EOF




# Function to create or modify dockeruser
setup_dockeruser() {
    local user_exists=$(id -u dockeruser 2>/dev/null)
    local group_exists=$(getent group 65000)

    if [ -z "$group_exists" ]; then
        echo "Creating group 'dockeruser' with GID 65000..."
        groupadd -g 65000 dockeruser
    fi

    if [ -z "$user_exists" ]; then
        # If user does not exist, create it
        echo "Creating user 'dockeruser' with UID and GID 65000..."
        useradd -u 65000 -g 65000 -m dockeruser
    else
        # If user exists, check UID and GID
        local current_uid=$(id -u dockeruser)
        local current_gid=$(id -g dockeruser)
        if [ "$current_uid" -ne 65000 ] || [ "$current_gid" -ne 65000 ]; then
            echo "Adjusting UID and GID for 'dockeruser'..."
            usermod -u 65000 dockeruser
            groupmod -g 65000 dockeruser
        fi
    fi
}


# Call the setup function
setup_dockeruser

# Change ownership and permissions of the project directory
echo "Changing ownership and permissions of $PROJECT_NAME..."
chown dockeruser:dockeruser "../$PROJECT_NAME" -R
chmod 770 "../$PROJECT_NAME" -R


echo "Setup complete."


echo "Project $PROJECT_NAME has been set up successfully."
