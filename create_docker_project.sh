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
        rm -rf "$PROJECT_NAME"
    else
        echo "Error: Project directory '$PROJECT_NAME' already exists. Use --overwrite-existing-project to overwrite."
        exit 1
    fi
fi

# Create project structure
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

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

# Copy .bashrc file
COPY .bashrc /usr/src/project/.bashrc

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






# Create a .bashrc file
cat > .devcontainer/.bashrc <<EOF
# If not running interactively, don't do anything
case \$- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "\$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "\${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=\$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "\$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "\$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "\$color_prompt" = yes ]; then
    PS1='\${debian_chroot:+(\$debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\\$ '
else
    PS1='\${debian_chroot:+(\$debian_chroot)}\u@\h:\w\\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "\$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;\${debian_chroot:+(\$debian_chroot)}\u@\h: \w\a\]\$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "\$(dircolors -b ~/.dircolors)" || eval "\$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "\$([ \$? = 0 ] && echo terminal || echo error)" "\$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert\$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi


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
echo "Show current pip freeze into requirements.txt"
/usr/src/venvs/app-main/bin/pip freeze > /usr/src/project/app-main/requirements.txt

echo "Getting git submodules"
git submodule init && git submodule update

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
DOCKERUSER_HOME=/usr/src/project
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
DOCKERUSER_HOME=\${DOCKERUSER_HOME:-/usr/src/project}
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
