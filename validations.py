# validations.py
import sys
import re

def validate_project_name(project_name: str):
    """
    Must contain only [a-z0-9-], cannot start or end with digit or dash.
    """
    pattern = r'^[a-z]+[a-z0-9-]*[a-z0-9]$'
    if not re.match(pattern, project_name):
        print("Error: Project name must contain only lowercase letters a-z, "
              "digits 0-9, and dashes (-), and cannot start or end with a digit or dash.")
        sys.exit(1)
