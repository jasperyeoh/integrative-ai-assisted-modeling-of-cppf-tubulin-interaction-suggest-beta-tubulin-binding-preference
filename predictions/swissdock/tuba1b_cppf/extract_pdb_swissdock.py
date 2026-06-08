#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re

def split_swissdock_results(input_file):
    """
    将 SwissDock 的对接结果按 CLUSTER_NUM 和 CLUSTER_MEMBER 拆分成多个 .pdb 文件。
    文件名格式：num{cluster_num}mem{cluster_member}.pdb
    """
    # 用于存储当前 pose 的所有行
    current_pose_lines = []
    
    # 默认的 cluster_num、cluster_member（如果尚未获取到就先存 None）
    cluster_num = None
    cluster_member = None
    
    # 正则匹配用来解析数字
    #   例：REMARK CLUSTER_NUM : 3  ->  group(1) = 3
    cluster_num_pattern = re.compile(r'^REMARK CLUSTER_NUM\s*:\s*(\d+)')
    cluster_member_pattern = re.compile(r'^REMARK CLUSTER_MEMBER\s*:\s*(\d+)')
    file_name_pattern = re.compile(r'^REMARK FILE_NAME : (.*)')  # 如果需要也可提取文件名

    def write_pose_to_file(lines, cnum, cmem):
        """将缓存的行写入对应文件"""
        if not lines:
            return
        out_filename = f"${LOCAL_WORKSPACE}peryeoh/Desktop/Research/TUB_CPPF/swissdock/swissdock_tuba1b/tuba1b_cppf_27dec/extracted_pdb/num{cnum}mem{cmem}.pdb"
        with open(out_filename, 'w') as f_out:
            f_out.writelines(lines)
        print(f"已输出: {out_filename} ({len(lines)} 行)")

    with open(input_file, 'r') as f_in:
        for line in f_in:
            # 如果检测到 'REMARK FILE_NAME :' 说明是一个新 pose 的开始
            if line.startswith("REMARK FILE_NAME :"):
                # 如果 current_pose_lines 不为空，说明上一 pose 还没写出
                # 先把上一 pose 写到文件
                if current_pose_lines and cluster_num is not None and cluster_member is not None:
                    write_pose_to_file(current_pose_lines, cluster_num, cluster_member)
                
                # 开启新的 pose 缓存
                current_pose_lines = [line]
                # 重置 cluster_num, cluster_member
                cluster_num = None
                cluster_member = None

            else:
                # 不管怎样，这一行先暂存
                current_pose_lines.append(line)

            # 如果这行包含 CLUSTER_NUM，就提取数值
            match_cnum = cluster_num_pattern.match(line)
            if match_cnum:
                cluster_num = match_cnum.group(1)

            # 如果这行包含 CLUSTER_MEMBER，就提取数值
            match_cmem = cluster_member_pattern.match(line)
            if match_cmem:
                cluster_member = match_cmem.group(1)

        # 文件读取结束后，若缓存里还有最后一个 pose，则写到文件
        if current_pose_lines and cluster_num is not None and cluster_member is not None:
            write_pose_to_file(current_pose_lines, cluster_num, cluster_member)


if __name__ == "__main__":
    input_filename = "${LOCAL_WORKSPACE}peryeoh/Desktop/Research/TUB_CPPF/swissdock/swissdock_tuba1b/tuba1b_cppf_27dec/result.dock4"
    split_swissdock_results(input_filename)