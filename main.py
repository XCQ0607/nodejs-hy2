import os
import subprocess
import sys
import shutil

# ==============================================================================
# Helper functions for dependency check and installation
# ==============================================================================

def command_exists(cmd):
    """Check if a command exists in the system path."""
    return shutil.which(cmd) is not None

def install_dependencies():
    """Attempt to install system dependencies if missing."""
    print(">>> [Python Runtime] Checking system dependencies...")
    
    needed = ["bash", "curl", "node"]
    missing = [cmd for cmd in needed if not command_exists(cmd)]
    
    if not missing:
        print(">>> [Python Runtime] Basic dependencies found: " + ", ".join(needed))
        return

    print(f">>> [Python Runtime] Missing dependencies: {', '.join(missing)}. Attempting to install...")
    
    # Try to detect package manager
    try:
        if command_exists("apk"):
            print(">>> [Python Runtime] Detected Alpine Linux. Using apk...")
            # Alpine needs 'nodejs' package name usually
            pkg_map = {"node": "nodejs"}
            packages = [pkg_map.get(m, m) for m in missing] + ["openssl"]
            subprocess.run(["apk", "update"], check=True)
            subprocess.run(["apk", "add", "--no-cache"] + packages, check=True)
        elif command_exists("apt-get"):
            print(">>> [Python Runtime] Detected Debian/Ubuntu. Using apt-get...")
            # Debian/Ubuntu needs 'nodejs'
            pkg_map = {"node": "nodejs"}
            packages = [pkg_map.get(m, m) for m in missing] + ["openssl"]
            subprocess.run(["apt-get", "update"], check=True)
            subprocess.run(["apt-get", "install", "-y"] + packages, check=True)
        elif command_exists("yum"):
            print(">>> [Python Runtime] Detected CentOS/RHEL. Using yum...")
            pkg_map = {"node": "nodejs"}
            packages = [pkg_map.get(m, m) for m in missing] + ["openssl"]
            subprocess.run(["yum", "install", "-y"] + packages, check=True)
        else:
            print(">>> [Python Runtime] Warning: Unknown package manager. Please ensure prerequisites (bash, curl, node) are installed.")
    except subprocess.CalledProcessError as e:
        print(f">>> [Python Runtime] Failed to install dependencies: {e}")

# ==============================================================================
# Main execution flow
# ==============================================================================

def main():
    try:
        # 1. Self-Check and Install
        install_dependencies()

        # 2. Check for start.sh
        script_file = "start.sh"
        if os.path.exists(script_file):
            # Ensure it is executable on Unix systems
            if os.name != 'nt':
                os.chmod(script_file, 0o755)
                print(f">>> [Python Runtime] Set execution permission for {script_file}")
        else:
            print(f">>> [Python Runtime] Error: {script_file} not found!")
            sys.exit(1)

        # 3. Start the project
        print(f">>> [Python Runtime] Starting project via {script_file}...")
        
        # Use subprocess.Popen to stream output in real-time
        # In case bash is missing but sh works (for very minimal environments)
        shell_cmd = "bash" if command_exists("bash") else "sh"
        
        process = subprocess.Popen(
            [shell_cmd, script_file],
            stdout=sys.stdout,
            stderr=sys.stderr,
            universal_newlines=True
        )
        
        # Wait for the process to finish
        exit_code = process.wait()
        print(f">>> [Python Runtime] Project exited with code {exit_code}")
        sys.exit(exit_code)

    except KeyboardInterrupt:
        print("\n>>> [Python Runtime] Interrupted by user. Shutting down...")
        sys.exit(0)
    except Exception as e:
        print(f">>> [Python Runtime] Fatal error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
