# Grafana Dashboard Gallery

This page showcases the pre-built Grafana dashboards included with the `puppet_data_connector_enhancer` module.

## Overview Dashboard

The main status dashboard provides a comprehensive view of your Puppet infrastructure health and metrics.

![Overview Dashboard](images/overview%20dashboard.png)

## CIS Compliance Dashboard

Track CIS benchmark compliance scores across all managed nodes with historical trending.

![CIS Dashboard](images/cis%20dashboard.png)

## Node Detail Dashboard

Detailed metrics and information for individual nodes including configuration version, OS details, and patch status.

![Node Detail](images/node%20detail.png)

## OS Overview Dashboard

Visualise operating system distribution and versions across your Puppet infrastructure.

![OS Overview](images/os%20overview.png)

## Patch Management Dashboards

### Patch Dashboard #1 - Overview

High-level view of patch status across all nodes, showing available updates and security patches.

![Patch Dashboard 1](images/patch%20dashboard%20%231.png)

### Patch Dashboard #2 - Groups

Patch management organised by patch groups for controlled deployment.

![Patch Dashboard 2](images/patch%20dashboard%20%232.png)

### Patching Detail

Detailed package-level information showing specific updates available for each node.

![Patching Detail](images/patching%20detail.png)

## Reboot/Restart Dashboard

Track which nodes require system reboots or application restarts after updates.

![Reboot/Restart](images/reboot%3Arestart.png)

## Installation

All dashboard JSON files are located in the `files/` directory of the module:

1. Copy JSON files from: `puppet_data_connector_enhancer/files/*.json`
2. In Grafana: **Dashboards** → **Import**
3. Upload JSON or paste contents
4. Select your Prometheus data source
5. Click **Import**

## Dashboard Features

- **Infrastructure filters**: All dashboards support filtering by `puppet_server`, `scm_server`, `grafana_server`, and `cd4pe_server` for multi-environment deployments
- **Time range selection**: Standard Grafana time controls for historical analysis
- **Auto-refresh**: Dashboards automatically update to show latest metrics
- **Drilldown navigation**: Click through from overview to detailed dashboards

## Customisation

These dashboards are provided as starting templates. You can:

- Modify panels and queries to suit your needs
- Add additional metrics from your Prometheus instance
- Adjust thresholds and alert conditions
- Export modified versions for sharing across your organisation

For more information, see the main [README.md](README.md).
