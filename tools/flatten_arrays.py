#!/usr/bin/env python3
"""Flatten 2D arrays in tb_safety_island_top_full.v for Icarus 0.9.7"""
import re

filepath = "../tb/tb_safety_island_top_full.v"
with open(filepath, "r", encoding="utf-8", errors="replace") as f:
    content = f.read()

# Replace declarations
content = content.replace(
    "reg [DATA_W-1:0] ext_mem [0:NUM_MASTERS-1][0:MEM_WORDS-1];",
    "reg [DATA_W-1:0] ext_mem [0:(NUM_MASTERS*MEM_WORDS)-1];")
content = content.replace(
    "reg [ID_W-1:0]   q_id    [0:NUM_MASTERS-1][0:Q_DEPTH-1];",
    "reg [ID_W-1:0]   q_id    [0:(NUM_MASTERS*Q_DEPTH)-1];")
content = content.replace(
    "reg [ADDR_W-1:0] q_addr  [0:NUM_MASTERS-1][0:Q_DEPTH-1];",
    "reg [ADDR_W-1:0] q_addr  [0:(NUM_MASTERS*Q_DEPTH)-1];")
content = content.replace(
    "reg [7:0]        q_len   [0:NUM_MASTERS-1][0:Q_DEPTH-1];",
    "reg [7:0]        q_len   [0:(NUM_MASTERS*Q_DEPTH)-1];")
content = content.replace(
    "reg [1:0]        q_burst [0:NUM_MASTERS-1][0:Q_DEPTH-1];",
    "reg [1:0]        q_burst [0:(NUM_MASTERS*Q_DEPTH)-1];")
content = content.replace(
    "reg [7:0]        q_beat  [0:NUM_MASTERS-1][0:Q_DEPTH-1];",
    "reg [7:0]        q_beat  [0:(NUM_MASTERS*Q_DEPTH)-1];")
content = content.replace(
    "reg              q_err   [0:NUM_MASTERS-1][0:Q_DEPTH-1];",
    "reg              q_err   [0:(NUM_MASTERS*Q_DEPTH)-1];")

# Replace access patterns - ext_mem[master][addr] -> ext_mem[master*MEM_WORDS + addr]
# Pattern: ext_mem[ <expr> ][ <expr> ]
def replace_ext_mem(m):
    m_idx = m.group(1)
    w_idx = m.group(2)
    return f"ext_mem[({m_idx}) * MEM_WORDS + ({w_idx})]"

content = re.sub(r'ext_mem\[([^\]]+)\]\[([^\]]+)\]', replace_ext_mem, content)

# Pattern: q_id[master][pos] -> q_id[master*Q_DEPTH + pos]
def replace_q(name):
    def replacer(m):
        m_idx = m.group(1)
        pos = m.group(2)
        return f"{name}[({m_idx}) * Q_DEPTH + ({pos})]"
    return replacer

for qname in ['q_id', 'q_addr', 'q_len', 'q_burst', 'q_beat', 'q_err']:
    content = re.sub(
        rf'{qname}\[([^\]]+)\]\[([^\]]+)\]',
        replace_q(qname),
        content)

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)

print("Flattened 2D arrays in", filepath)
