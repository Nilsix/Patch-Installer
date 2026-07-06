import subprocess
import os


BASE_DIR = os.path.dirname(os.path.abspath(__file__))

subprocess.run(["git","-C",BASE_DIR,"clone","https://github.com/Nilsix/BROS-Patch.git"])