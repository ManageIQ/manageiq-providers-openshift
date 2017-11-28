# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)


## Gaprindashvili Beta2

### Fixed
- Fix Inventory Collector has_required_role? [(#65)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/65)

## Gaprindashvili Beta1

### Added
- Prometheus alerts [(#22)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/22)
- Container Template: Parse object_labels [(#25)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/25)
- Use the kubernetes options for Openshift [(#32)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/32)
- Add openshift persister and test also batch saver strategy [(#39)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/39)
- Run provider generator to sync changes from core [(#38)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/38)
- Openshift graph refresh [(#34)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/34)
- Add a setting to only send DELETED notices [(#61)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/61)

## Fixed
- Don't start CollectorWorker if Graph Refresh disabled [(#60)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/60)
- Disable inventory collector worker by default [(#63)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/63)

### Removed
- Remove hawkular support for inventory collection [(#49)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/49)

## Initial changelog added
