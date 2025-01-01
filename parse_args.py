# parse_args.py
import argparse

def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Create a base Docker devcontainer project."
    )
    parser.add_argument(
        "--projectname", 
        type=str, 
        required=True, 
        help="Specify the project name."
    )
    parser.add_argument(
        "--overwrite-existing-project",
        action="store_true",
        help="Overwrite existing project directory if it already exists."
    )
    return parser.parse_args()
