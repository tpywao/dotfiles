#!/usr/bin/env python3
# WIP
import sys
import subprocess
from argparse import ArgumentParser


def init_parser():
    parser = ArgumentParser()
    parser.add_argument("commit_msg_file")
    parser.add_argument("commit_source")
    parser.add_argument("sha1")
    return parser


def get_args():
    parser = init_parser()
    args = parser.parse_args()
    commit_msg_file = args.commit_msg_file

    current_branch = (
        subprocess.check_output(["git", "branch", "--show-current"]).decode().strip()
    )
    branch_elements = current_branch.split("/")
    if len(branch_elements) == 1:
        return (commit_msg_file, current_branch)
    elif len(branch_elements) == 2:
        ticket_name = branch_elements[1]
        return (commit_msg_file, ticket_name)
    else:
        return (commit_msg_file, branch_elements[2])


def is_mac():
    return "darwin" in sys.platform


if __file__ == "__main__":
    commit_msg_file, ticket_name = get_args()
    with open(commit_msg_file, "r+") as file:
        first_line = file.readline().strip()
        if first_line:
            # 一行目が空行であれば（--amendでなければ）以下を実行
            pass
        else:
            # WIP: このコードよくわからん(write by copilot)
            file.seek(0)
            content = file.read()
            file.seek(0)
            file.write(f"{ticket_name} {content}")
            file.truncate()
