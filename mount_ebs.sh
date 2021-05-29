#!/bin/bash
read -r -d '' script <<-"EOF"
################
""""
Author: Lahiru Sellapperumage
Email: lahirushanaka@gmail.com
version: 1.0,
Created:5/18/2021
"""
import subprocess, requests, json, os, time, logging, shutil, sys
#List of disk and sizes to mount


####
logging.basicConfig(filename="/var/log/ebsmount.log",\
                    filemode='a', format='%(asctime)s,%(msecs)d %(name)s %(levelname)s %(message)s',\
                    datefmt= '%H:%M:%S',
                    level= logging.DEBUG)
logger = logging.getLogger("ebsmount")
####


def run_shell_command(cmd):
    process = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    logging.info("Executing Shell Command - " + cmd)
    output = process.communicate()[0]
    exitCode = process.returncode

    if (exitCode == 0):
        logging.info("Command Execution is completed for " + cmd)
        return output
    else:
        logging.error("Execution failed with : " + cmd)
        logging.error(output)
        raise RuntimeError("%r failed, Exit status: %d" % (cmd, exitCode))

def check_mount(mount_value):
    logging.info("Check mount state of " + mount_value)
    with open('/proc/mounts') as f:
        datafile = f.readlines()
    found = False
    for line in datafile:
        if mount_value in line:
            logging.info("Mount Point is already mount - " + mount_value)
            return True
    logging.info("Mount point is not mounted " + mount_value)
    return False
def ebs_mount(vid,mdir):
    lsblk_cmd = "lsblk  -o NAME,SERIAL|grep %s|awk '{print $1}'" % vid
    lsblk_proc = run_shell_command(lsblk_cmd)
    device_name = "/dev/%s" % lsblk_proc.strip()
    fsystem_check_cmd = "file -s %s" % device_name
    fsystem_check_proc = run_shell_command(fsystem_check_cmd)
    uuid = ""

    if "Linux" in fsystem_check_proc:
        print("FileSystem is Already created")
        logging.info("FileSystem is Already created")
        uuid_cmd = "lsblk -f |grep %s|awk '{print $3}'" % lsblk_proc.strip()
        uuid = run_shell_command(uuid_cmd).strip()
        logging.info("Checking UUID is EMPTY or Not")
        if uuid == "": print("UUID is EMPTY, Exiting..."),logging.error("UUID is Empty Value for " + device_name), exit(1)
        print(uuid)
        logging.info("UUID " + uuid)
        #uuid = subprocess.Popen(uuid_cmd, stdout=subprocess.PIPE, shell=True).stdout.read().strip()
        fs_tab_line = "UUID=%s %s ext4 defaults 0 0" % (uuid, mdir)
        print(fs_tab_line)

        with open("/etc/fstab", "a") as fstab_file:
            fstab_file.write(fs_tab_line + "\n")
        #subprocess.Popen("mount -a", stdout=subprocess.PIPE, shell=True).stdout.read()
        logging.info("/etc/fstab Modifiled with: " + fs_tab_line)
        run_shell_command("mount -a")
    elif "data" in fsystem_check_proc or "MPEG-4" in fsystem_check_proc:
        print("FileSystem Not Available, Creating....")
        logging.info("Creating Filesystem ext4 for - " + device_name)
        mkfs_cmd = "mkfs.ext4 %s" % device_name
        run_shell_command(mkfs_cmd)
        logging.info("Filesystem ext4 creation is completed for - " + device_name)
        logging.info("Waiting few seconds  till UUID is populate")
        time.sleep(30)
        uuid_cmd = "lsblk -f |grep %s|awk '{print $3}'" % lsblk_proc.strip()
        uuid = run_shell_command(uuid_cmd).strip()
        print(uuid)
        logging.info("Checking UUID is EMPTY or Not")
        if uuid == "": print("UUID is EMPTY, Exiting..."),logging.error("UUID is Empty Value for " + device_name), exit(1)
        logging.info("UUID " + uuid)
        fs_tab_line = "UUID=%s %s ext4 defaults 0 0" % (uuid, mdir)
        logging.info("/etc/fstab Modified with: " + fs_tab_line)
        with open("/etc/fstab", "a") as fstab_file:
            fstab_file.write(fs_tab_line + "\n")
        run_shell_command("mount -a")
    else:
        print("Error in Mounting, Please manually mount", vid)
        logging.info("Error in Mounting, Please manually mount" + fsystem_check_proc)
        exit(1)

def main():
    id_res = requests.get('http://169.254.169.254/latest/meta-data/instance-id')
    region_res = requests.get('http://169.254.169.254/latest/dynamic/instance-identity/document')
    INST_ID = id_res.text
    REGION = json.loads(region_res.text)['region']
    AWS_CLI_COMMAND = """sudo -H -u ssm-user bash -c 'aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=%s \
                                        Name=tag-key,Values=mount  --query "Volumes[*].{ID:VolumeId,Tag:Tags}" \
                                        --region %s --output json'""" % (INST_ID, REGION)
    logging.info("REGION")
    vol_info = run_shell_command(AWS_CLI_COMMAND)
    vol = json.loads(vol_info)
    logging.info(vol)
    vol_mount = {key['ID'].replace('-', ''): value['Value'] for key in vol for value in key['Tag'] if
                 value['Key'] == 'mount'}
    logging.info(vol_mount)

    time.sleep(30)
    for k, v in vol_mount.items():
        if check_mount(v):
            continue
        else:
            if not os.path.exists(v):
                os.makedirs(v)
                ebs_mount(k, v)
            elif os.path.exists(v):
                shutil.rmtree(v)
                os.makedirs(v)
                ebs_mount(k, v)


if __name__ == "__main__":
    main()
EOF
python -c "$script"
