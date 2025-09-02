#!/usr/bin/env python3
"""
Build script for Sendoria Discord Bot
Compiles discord_bot.py into SendoriaBot.exe
"""

import subprocess
import sys
import os
import shutil

def check_pyinstaller():
    """Check if PyInstaller is installed, install if needed"""
    try:
        import PyInstaller
        print("✅ PyInstaller found")
        return True
    except ImportError:
        print("⚠️  PyInstaller not found. Installing...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])
            print("✅ PyInstaller installed successfully")
            return True
        except subprocess.CalledProcessError:
            print("❌ Failed to install PyInstaller")
            print("Please install manually: pip install pyinstaller")
            return False

def build_executable():
    """Build the Discord bot executable"""
    print("\n🔨 Building SendoriaBot.exe (console version)...")
    
    # PyInstaller command for console version
    cmd_console = [
        sys.executable, "-m", "PyInstaller",
        "--onefile",           # Single executable
        "--console",           # Keep console window
        "--name", "SendoriaBot",  # Output name
        "discord_bot.py"       # Source file
    ]
    
    # PyInstaller command for background version
    cmd_background = [
        sys.executable, "-m", "PyInstaller",
        "--onefile",           # Single executable
        "--noconsole",         # No console window (background)
        "--name", "SendoriaBot_Silent",  # Output name
        "discord_bot.py"       # Source file
    ]
    
    try:
        # Build console version
        result_console = subprocess.run(cmd_console, capture_output=True, text=True)
        
        if result_console.returncode == 0:
            print("✅ Console version build successful!")
            
            # Check if console exe was created
            exe_path_console = os.path.join("dist", "SendoriaBot.exe")
            if os.path.exists(exe_path_console):
                print(f"✅ Console executable created: {exe_path_console}")
                
                # Optional: Copy to current directory
                current_exe = "SendoriaBot.exe"
                if os.path.exists(current_exe):
                    backup = "SendoriaBot_old.exe"
                    print(f"📁 Backing up old executable to {backup}")
                    shutil.copy2(current_exe, backup)
                
                print(f"📁 Copying new console executable to current directory")
                shutil.copy2(exe_path_console, current_exe)
                
            else:
                print("❌ Console executable not found after build")
                return False
        else:
            print("❌ Console build failed!")
            print("Error output:")
            print(result_console.stderr)
            return False
        
        # Build background version
        print("\n🔨 Building SendoriaBot_Silent.exe (background version)...")
        result_background = subprocess.run(cmd_background, capture_output=True, text=True)
        
        if result_background.returncode == 0:
            print("✅ Background version build successful!")
            
            # Check if background exe was created
            exe_path_background = os.path.join("dist", "SendoriaBot_Silent.exe")
            if os.path.exists(exe_path_background):
                print(f"✅ Background executable created: {exe_path_background}")
                
                # Copy to current directory
                silent_exe = "SendoriaBot_Silent.exe"
                print(f"📁 Copying background executable to current directory")
                shutil.copy2(exe_path_background, silent_exe)
                
            else:
                print("❌ Background executable not found after build")
                return False
        else:
            print("❌ Background build failed!")
            print("Error output:")
            print(result_background.stderr)
            return False
            
        print("\n✅ Both versions built successfully!")
        print("   - SendoriaBot.exe (shows console window)")
        print("   - SendoriaBot_Silent.exe (runs in background)")
            
    except Exception as e:
        print(f"❌ Build error: {e}")
        return False
    
    return True

def cleanup():
    """Clean up build artifacts"""
    print("\n🧹 Cleaning up build files...")
    
    dirs_to_remove = ["build", "__pycache__"]
    files_to_remove = ["SendoriaBot.spec", "SendoriaBot_Silent.spec"]
    
    for dir_name in dirs_to_remove:
        if os.path.exists(dir_name):
            shutil.rmtree(dir_name)
            print(f"🗑️  Removed {dir_name}/")
    
    for file_name in files_to_remove:
        if os.path.exists(file_name):
            os.remove(file_name)
            print(f"🗑️  Removed {file_name}")

def main():
    print("🚀 Sendoria Discord Bot Builder")
    print("=" * 40)
    
    # Check if source file exists
    if not os.path.exists("discord_bot.py"):
        print("❌ discord_bot.py not found in current directory")
        return False
    
    # Install PyInstaller if needed
    if not check_pyinstaller():
        return False
    
    # Build executable
    if not build_executable():
        return False
    
    # Clean up
    cleanup()
    
    print("\n🎉 Build process complete!")
    print("You now have two versions:")
    print("  • SendoriaBot.exe - Shows console window (good for debugging)")
    print("  • SendoriaBot_Silent.exe - Runs completely in background (no console)")
    
    return True

if __name__ == "__main__":
    try:
        success = main()
        if not success:
            sys.exit(1)
    except KeyboardInterrupt:
        print("\n⚠️  Build cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)
