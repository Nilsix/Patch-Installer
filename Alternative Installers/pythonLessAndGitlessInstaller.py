import subprocess
import os


BASE_DIR = os.path.dirname(os.path.abspath(__file__))

print("To use this launcher, you must have Python and Git already installed ")

flag = True


while flag : 
    answer = input("do you have Python and Git installed ? (Y/N) : ")
    answer = answer.upper()
    if answer == "Y":
        subprocess.run(["git","-C",BASE_DIR,"clone","https://github.com/Nilsix/BROS-Patch.git"])
        flag = False
    elif answer == "N":
        flag = False