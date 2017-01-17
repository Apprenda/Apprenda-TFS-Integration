# tfsbuild.py
# this updates the release version of the tfs integration and then builds the extension
import json
import os
import shutil
import argparse
import logging

# github issue #12 - we're forcing the change of the path now so relative files should work everywhere
# except probably mac osx
FILE_PATH = os.path.dirname(os.path.abspath(__file__))
os.chdir(FILE_PATH)

# check working directory, update as needed
# def check_working_directory():
#    filepath = os.path.dirname(os.path.realpath(__file__))
#    # no sense in checking, just change it for this execution.
#    # cwd = os.getcwd()
#    os.chdir(filepath)


# private method to help find the nth character in a string
# pretty genius - refer to here http://stackoverflow.com/a/1884151/918237
def findnth(haystack, needle, n):
    parts = haystack.split(needle, n + 1)
    if len(parts) <= n + 1:
        return -1
    return len(haystack) - len(parts[-1]) - len(needle)


# update the release version
def update_release_version(build_type=None, mock=False):
    try:
        # perform backup
        shutil.copyfile('../vss-extension.json', '../vss-extension.json.bak')
        # if no type is specified, do nothing
        if build_type is None:
            return
        # test path
        # since we changed the working directory before, this should work no sweat.
        with open('../vss-extension.json') as json_data:
            vssext = json.load(json_data)
        version = vssext.get('version')
        periodidx = findnth(version, '.', 1)
        major = int(version[0:version.find('.')])
        minor = int(version[version.find('.')+1:periodidx])
        build = int(version[periodidx+1:])
        logger.debug("Old version is {0}".format(version))
        logger.debug("Major version is {0}".format(major))
        logger.debug("Minor Version is {0}".format(minor))
        logger.debug("Build Version is {0}".format(build))
        newversion = version
        if build_type == 'major':
            newversion = "{0}.{1}.{2}".format(major+1, 0, 0)
        if build_type == 'minor':
            newversion = "{0}.{1}.{2}".format(major, minor+1, 0)
        if build_type == 'build':
            newversion = "{0}.{1}.{2}".format(major, minor, build+1)
        if mock:
            logger.info('New version will be {0}'.format(newversion))
            return
    except:
        raise


# this copies the common.ps1 function out into the task directories that require it.
def deploy_common_updates():
    destinations = ['apprendaDemote', 'apprendaDeploy', 'apprendaPromote', 'apprendaScale']
    for destination in destinations:
        shutil.copyfile('../common/common.ps1', '../apprendaTasks/{0}/common.ps1'.format(destination))


def run(build_type, mock=False):
    if build_type != 'rebuild':
        update_release_version(build_type, mock)
    if not mock:
        deploy_common_updates()
        build_extension()


def build_extension():
    from subprocess import Popen, PIPE
    # give me the cwd and change it to the parent
    parent = os.path.abspath(os.path.join(os.getcwd(), os.pardir))
    p = Popen(['tfx', 'extension', 'create', '--manifest-blobs', r'..\vss-extension.json', '--output-path', 'bin/'], stdout=PIPE, stderr=PIPE, shell=True, cwd=parent)
    logger.info(p.communicate())

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Updates release information, and builds the Apprenda TFS extension.')
    parser.add_argument('build_type', type=str, choices=['major', 'minor', 'build', 'rebuild'], help='Specify the build type. Values: major | minor | build | rebuild. Rebuild does not increment version.')
    parser.add_argument('--test', dest='runtest', action='store_true', help='Run through the plan, but do not execute.')
    parser.add_argument('-v', dest='verbose', action='store_true', help='set verbosity to DEBUG level')
    parser.add_argument('-b', dest='nobackup', action='store_true', help='set this to not take a backup of the vss-extension.json file')
    args = parser.parse_args()
    logger = logging.getLogger('tfsbuild')
    fmt = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p')
    console = logging.StreamHandler()
    console.setFormatter(fmt)
    logger.addHandler(console)
    if args.verbose:
        logger.setLevel(logging.DEBUG)
        console.setLevel(logging.DEBUG)
        logger.debug("Debug is turned ON.")
    else:
        logger.setLevel(logging.INFO)
        console.setLevel(logging.INFO)
    logger.debug(args)
    # run it
    run(args.build_type, mock=args.runtest)
