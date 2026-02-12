# Changelog

All notable changes to this project are documented in this file.

## Unreleased

### Features

- **kubevirt-tpm** — Add TPM 2.0 support to KubeVirt plugin for LUKS disk encryption (`4c03fc0`, 2026-02-12)
  - Persistent TPM device, SMM features, and UEFI firmware on VMs
  - Inline MachineConfig for Clevis TPM2-based LUKS encryption in acm-ztp extraclustermanifests
- **imageDigestSources** — Replace deprecated `imageContentSources` with `imageDigestSources` in install-config (`2f0d0de`, 2026-02-12)
- **kubevirt-vlan** — Add VLAN support and restructure kubevirt VM networking (`d49c104`, 2026-02-11)
- **osimages-sync** — Replace CronJob polling with event-driven Jobs for osImages sync (`c2ba769`, 2026-02-10)
- **rhcos-osimages** — Add RHCOS osImages to ASC and per-cluster osImages ConfigMaps to ZTP/CAPI (`8893d16`, 2026-02-10)
- **kubevirt-cudn** — Use ClusterUserDefinedNetwork CRD for proper UDN Localnet support (`75de7a2`, 2026-02-10)

### Fixes

- **rhcos-iso-fix** — Fix RHCOS ISO URL: `rhcos-live.iso` -> `rhcos-live-iso.iso` (`de0e560`, 2026-02-11)
- **sno-fix** — Fix baremetal platform include to handle SNO without VIPs (`184de11`, 2026-02-10)

## v2.6.6 (2026-02-09)

- Fix UDN validation: disable IPAM for externally-managed VM IPs
- UDN networking for kubevirt
- Replace linux-bridge NAD with OVN UserDefinedNetwork in kubevirt template
- Fix arch normalization in ACM templates for RFC 1123 compliance
