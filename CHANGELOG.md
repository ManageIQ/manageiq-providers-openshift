# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)


## Hammer Beta-1

### Added
- Handle deleted entities [(#116)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/116)
- Updates for streaming service catalog [(#113)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/113)
- Add plugin display name [(#107)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/107)
- Streaming refresh for openshift using watches [(#103)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/103)
- Persister: InventoryCollection building through add_collection() [(#100)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/100)
- We need to use existing relation to project so we build valid query [(#79)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/79)

## Gaprindashvili-1 - Released 2018-01-31

### Added
- Tag mapping in graph refresh [(#64)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/64)
- Prometheus alerts [(#22)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/22)
- Container Template: Parse object_labels [(#25)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/25)
- Use the kubernetes options for Openshift [(#32)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/32)
- Add openshift persister and test also batch saver strategy [(#39)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/39)
- Run provider generator to sync changes from core [(#38)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/38)
- Openshift graph refresh [(#34)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/34)
- Add a setting to only send DELETED notices [(#61)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/61)

### Fixed
- Added supported_catalog_types [(#177)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/177)
- Fix Inventory Collector has_required_role? [(#65)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/65)
- Don't start CollectorWorker if Graph Refresh disabled [(#60)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/60)
- Disable inventory collector worker by default [(#63)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/63)

### Removed
- Remove hawkular support for inventory collection [(#49)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/49)

## Initial changelog added 2017-08-15
