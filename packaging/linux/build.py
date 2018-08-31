#!/usr/bin/env python3
"""Build package for specific platform. Checks out GitHub repository at 
specific tag and runs associated build scripts. 

Usage:
  build.py (snap|debian) [--force-version <version>] [-- [ARGS ...]]

Examples:
  Build debian package for Ubuntu 16.04:
    python3 build.py debian -- xenial

  Build snap package:
    python3 build.py snap

  Ignore current tag and force version:
    python3 build.py snap --force-version=v0.99.7

Dependencies:
  - git
  - python3
  - python3-docopt
"""
import subprocess
import functools
import tempfile
import docopt
import shutil
import json
import os

ROOT = os.path.realpath(os.path.join(os.path.dirname(__file__), "../.."))

GITHUB_REPO = "clash-compiler"

def parse_tag(tag_name):
    """Parse tag of either of these formats:
        
     * v0.1.2 
     * v0.1
     
    where the numbers can be of arbitrary size. Returns a tuple containing the base
    and subversion indicated by the tag. For the examples:
        
     * ("0.1", "2")
     * ("0.1", "0")

    """
    try:
        tag_name_splitted = list(map(int, tag_name[1:].split(".")))
    except:
        raise ValueError("Could not interpret tag: {}. Is it of the form vX.Y.Z?".format(tag_name))

    if len(tag_name_splitted) == 2:
        base_version = ".".join(map(str, tag_name_splitted))
        sub_version = "0"
    elif len(tag_name_splitted) == 3:
        base_version = ".".join(map(str, tag_name_splitted[:2]))
        sub_version = tag_name_splitted[2]
    else:
        raise ValueError("Could not interpret tag: {}. Is it of the form vX.Y.Z?".format(tag_name))

    return base_version, sub_version

def clone(target_directory):
    shutil.copytree(ROOT, os.path.join(target_directory, GITHUB_REPO))

def build(platform, package, version, args):
    base_version, sub_version = version
    base_cmd = "packaging/{platform}/{package}/run.sh {base_version} {sub_version}".format(**locals())
    subprocess.check_call(base_cmd.split() + args)

if __name__ == '__main__':
    args = docopt.docopt(__doc__)

    current_tag = subprocess.run(["git", "describe", "--tags"], stdout=subprocess.PIPE, check=True)
    current_tag = current_tag.stdout.decode().strip()

    if args["snap"]:
        package = "snap"
    elif args["debian"]:
        package = "debian"
    else:
        raise RuntimeError("Unreachable?")

    if args["--force-version"]:
        tag_name = args["<version>"]
    else:
        tag_name = current_tag

    version = parse_tag(tag_name)

    with tempfile.TemporaryDirectory(prefix="clash-package-build-") as tempdir:
        clone(tempdir)
        os.chdir(tempdir)
        os.chdir(GITHUB_REPO)
        build("linux", package, version, args["ARGS"])
