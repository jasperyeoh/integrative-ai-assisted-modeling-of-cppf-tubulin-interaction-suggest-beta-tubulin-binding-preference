#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
import csv

def extract_pose_data(dock4_file, csv_file):
    # 定义正则表达式，逐行匹配数值
    pattern_cluster_num = re.compile(r'^REMARK CLUSTER_NUM\s*:\s*(\d+)')
    pattern_cluster_member = re.compile(r'^REMARK CLUSTER_MEMBER\s*:\s*(\d+)')
    pattern_member_energy = re.compile(r'^REMARK MEMBER_ENERGY\s*:\s*([\-\d\.]+)')
    pattern_member_score = re.compile(r'^REMARK MEMBER_SCORE\s*:\s*([\-\d\.]+)')
    pattern_spdg = re.compile(r'^REMARK SP-dG\s*:\s*([\-\d\.]+)')
    pattern_rmsd = re.compile(r'^REMARK RMSD\s*:\s*([\-\d\.]+)')
    pattern_polar = re.compile(r'^REMARK Polar\s*:\s*([\-\d\.]+)')
    pattern_nonpolar = re.compile(r'^REMARK Nonpolar\s*:\s*([\-\d\.]+)')
    pattern_inter = re.compile(r'^REMARK Inter\s*:\s*([\-\d\.]+)')
    pattern_polar15 = re.compile(r'^REMARK Polar15\s*:\s*([\-\d\.]+)')
    pattern_file_name = re.compile(r'^REMARK FILE_NAME : (.+)$')

    # 用来存储所有 pose 信息的列表
    results = []

    # 当前正在解析的 pose 信息
    current_pose = {}

    def save_current_pose():
        """
        如果 current_pose 已经包含 cluster_num/cluster_member，就将其保存到 results。
        可以做一些校验，或者给缺失字段设置默认值。
        """
        if 'cluster_num' in current_pose and 'cluster_member' in current_pose:
            # 将当前 pose 的信息 dict 追加到 results 列表
            results.append({
                'file_name': current_pose.get('file_name'),
                'cluster_num': current_pose.get('cluster_num'),
                'cluster_member': current_pose.get('cluster_member'),
                'member_energy': current_pose.get('member_energy'),
                'member_score': current_pose.get('member_score'),
                'spdg': current_pose.get('spdg'),
                'rmsd': current_pose.get('rmsd'),
                'polar': current_pose.get('polar'),
                'nonpolar': current_pose.get('nonpolar'),
                'inter': current_pose.get('inter'),
                'polar15': current_pose.get('polar15'),
            })

    with open(dock4_file, 'r') as f_in:
        for line in f_in:
            # 如果遇到新 pose 的开始，就先保存上一个 pose
            match_file_name = pattern_file_name.match(line)
            if match_file_name:
                # 保存上一个 pose（如果已经存在）
                save_current_pose()
                # 开始新的 pose，清空 current_pose
                current_pose = {}
                current_pose['file_name'] = match_file_name.group(1).strip()

            # 按顺序匹配各种字段
            match_cnum = pattern_cluster_num.match(line)
            if match_cnum:
                current_pose['cluster_num'] = match_cnum.group(1)

            match_cmem = pattern_cluster_member.match(line)
            if match_cmem:
                current_pose['cluster_member'] = match_cmem.group(1)

            match_energy = pattern_member_energy.match(line)
            if match_energy:
                current_pose['member_energy'] = float(match_energy.group(1))

            match_score = pattern_member_score.match(line)
            if match_score:
                current_pose['member_score'] = float(match_score.group(1))

            match_sp = pattern_spdg.match(line)
            if match_sp:
                current_pose['spdg'] = float(match_sp.group(1))

            match_rmsd = pattern_rmsd.match(line)
            if match_rmsd:
                current_pose['rmsd'] = float(match_rmsd.group(1))

            match_polar = pattern_polar.match(line)
            if match_polar:
                current_pose['polar'] = float(match_polar.group(1))

            match_nonpolar = pattern_nonpolar.match(line)
            if match_nonpolar:
                current_pose['nonpolar'] = float(match_nonpolar.group(1))

            match_inter = pattern_inter.match(line)
            if match_inter:
                current_pose['inter'] = float(match_inter.group(1))

            match_polar15 = pattern_polar15.match(line)
            if match_polar15:
                current_pose['polar15'] = float(match_polar15.group(1))

        # 读到文件末尾，如果 current_pose 里还有数据，也要保存
        save_current_pose()

    # 将 results 中的数据写到 CSV
    fieldnames = [
        'file_name', 'cluster_num', 'cluster_member',
        'member_energy', 'member_score', 'spdg', 'rmsd',
        'polar', 'nonpolar', 'inter', 'polar15'
    ]

    with open(csv_file, 'w', newline='') as f_out:
        writer = csv.DictWriter(f_out, fieldnames=fieldnames)
        writer.writeheader()
        for pose in results:
            writer.writerow(pose)

    print(f"提取了 {len(results)} 个 pose，保存到 {csv_file}.")


if __name__ == "__main__":
    dock4_input = "${LOCAL_WORKSPACE}peryeoh/Desktop/Research/TUB_CPPF/swissdock/tub_dimer_cppf/result.dock4"
    csv_output = "${LOCAL_WORKSPACE}peryeoh/Desktop/Research/TUB_CPPF/swissdock/tub_dimer_cppf/dimer_pose_data.csv"
    extract_pose_data(dock4_input, csv_output)