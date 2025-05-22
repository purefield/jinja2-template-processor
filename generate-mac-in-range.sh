#!/usr/bin/env python3

import yaml
import sys
import argparse
import os
import random

def mac_str_to_int(mac):
    return int(mac.replace(":", ""), 16)

def mac_int_to_str(mac_int):
    hex_str = f"{mac_int:012x}"
    return ":".join(hex_str[i:i+2] for i in range(0, 12, 2)).upper()

def assign_unique_random_macs(yaml_data, range_start, range_end):
    start = mac_str_to_int(range_start)
    end = mac_str_to_int(range_end)

    all_interfaces = []
    for host_data in yaml_data.get("hosts", {}).values():
        interfaces = host_data.get("network", {}).get("interfaces", [])
        all_interfaces.extend(interfaces)

    needed = len(all_interfaces)
    available = end - start + 1
    if needed > available:
        raise ValueError(f"Not enough MAC addresses in range ({available}) for interfaces ({needed})")

    # Generate all possible MACs in range
    mac_pool = list(range(start, end + 1))
    random.shuffle(mac_pool)

    # Assign unique random MACs
    for iface, mac_int in zip(all_interfaces, mac_pool):
        iface["macAddress"] = mac_int_to_str(mac_int)

    return yaml_data

def main():
    parser = argparse.ArgumentParser(description="Assign unique random MAC addresses in YAML")
    parser.add_argument("--range-start", default=os.getenv("RANGE_START"),
                        help="Start MAC address (e.g., 00:1A:2B:00:00:01)")
    parser.add_argument("--range-end", default=os.getenv("RANGE_END"),
                        help="End MAC address (e.g., 00:1A:2B:00:00:FF)")
    args = parser.parse_args()

    if not args.range_start or not args.range_end:
        print("Error: You must provide --range-start and --range-end or set RANGE_START and RANGE_END in the environment.", file=sys.stderr)
        sys.exit(1)

    input_yaml = sys.stdin.read()
    data = yaml.safe_load(input_yaml)
    updated = assign_unique_random_macs(data, args.range_start, args.range_end)
    yaml.dump(updated, sys.stdout, sort_keys=False)

if __name__ == "__main__":
    main()

