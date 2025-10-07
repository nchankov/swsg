#!/bin/bash
# env-loader.sh - Shared environment loading functions

# Function to load environment from project directory
load_project_env() {
    local project_dir="$1"
    if [ -z "$project_dir" ]; then
        echo "Error: Project directory not specified"
        exit 1
    fi
    
    if [ ! -d "$project_dir" ]; then
        echo "Error: Project directory '$project_dir' does not exist"
        exit 1
    fi
    
    local env_file="$project_dir/.env"
    if [ ! -f "$env_file" ]; then
        echo "Error: .env file not found in project directory '$project_dir'"
        exit 1
    fi
    
    echo "Loading environment from: $env_file"
    export $(grep -v '^#' "$env_file" | xargs)
}

# Function to parse project parameter from command line arguments
parse_project_args() {
    local project_dir=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project)
                project_dir="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: $0 --project <project_directory>"
                exit 1
                ;;
        esac
    done
    echo "$project_dir"
}

# Function to load environment with fallback to local .env
load_env_with_fallback() {
    local project_dir="$1"
    local script_dir="$2"
    
    if [ -n "$project_dir" ]; then
        load_project_env "$project_dir"
    else
        # Fallback to loading local .env for backward compatibility
        if [ -f "$script_dir/.env" ]; then
            export $(grep -v '^#' "$script_dir/.env" | xargs)
        fi
    fi
}