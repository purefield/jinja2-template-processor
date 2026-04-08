#!/usr/bin/env python3

import argparse
import hashlib
import os
import sys

import yaml

def mac_str_to_int(mac):
    return int(mac.replace(":", ""), 16)

def mac_int_to_str(mac_int):
    hex_str = f"{mac_int:012x}"
    return ":".join(hex_str[i:i+2] for i in range(0, 12, 2)).upper()

def identity_to_mac_start(identity, start, size):
    digest = hashlib.sha256(identity.encode("utf-8")).digest()
    return start + (int.from_bytes(digest, "big") % size)

def iter_interfaces(yaml_data):
    cluster = yaml_data.get("cluster") or {}
    network = yaml_data.get("network") or {}
    hosts = yaml_data.get("hosts") or {}
    cluster_name = cluster.get("name")
    network_domain = network.get("domain")

    if not cluster_name:
        raise ValueError("Missing cluster.name in clusterfile")
    if not network_domain:
        raise ValueError("Missing network.domain in clusterfile")

    for host_name in sorted(hosts):
        host_data = hosts.get(host_name) or {}
        interfaces = ((host_data.get("network") or {}).get("interfaces") or [])
        seen_names = set()

        for iface in sorted(interfaces, key=lambda item: item.get("name", "")):
            iface_name = iface.get("name")
            if not iface_name:
                raise ValueError(f"Host {host_name} has an interface without a name")
            if iface_name in seen_names:
                raise ValueError(f"Host {host_name} has duplicate interface name {iface_name}")
            seen_names.add(iface_name)
            identity = f"{cluster_name}|{network_domain}|{host_name}|{iface_name}"
            yield identity, iface

def assign_unique_deterministic_macs(yaml_data, range_start, range_end):
    start = mac_str_to_int(range_start)
    end = mac_str_to_int(range_end)
    if start > end:
        raise ValueError("RANGE_START is greater than RANGE_END")

    interfaces = list(iter_interfaces(yaml_data))
    available = end - start + 1
    needed = len(interfaces)

    if needed > available:
        raise ValueError(f"Not enough MAC addresses in range ({available}) for interfaces ({needed})")

    assigned = set()
    for identity, iface in interfaces:
        mac_int = identity_to_mac_start(identity, start, available)
        for _ in range(available):
            if mac_int not in assigned:
                assigned.add(mac_int)
                iface["macAddress"] = mac_int_to_str(mac_int)
                break
            mac_int = start if mac_int == end else mac_int + 1
        else:
            raise ValueError(f"Unable to assign a unique MAC for {identity}")

    return yaml_data

def main():
    parser = argparse.ArgumentParser(description="Assign deterministic MAC addresses in YAML")
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
    if data is None:
        print("Error: No YAML input provided.", file=sys.stderr)
        sys.exit(1)

    updated = assign_unique_deterministic_macs(data, args.range_start, args.range_end)
    yaml.dump(updated, sys.stdout, sort_keys=False)

if __name__ == "__main__":
    main()
