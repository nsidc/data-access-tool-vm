<p align="center">
  <img alt="NSIDC logo" src="https://nsidc.org/themes/custom/nsidc/logo.svg" width="150" />
</p>

# Data Access Tool VM

NSIDC VM configuration for the Data Access Tool (DAT).

The DAT is composed of:

* [data-access-tool-ui](https://github.com/nsidc/data-access-tool-ui)
* [data-access-tool-backend](https://github.com/nsidc/data-access-tool-backend)

This VM project deploys the backend. The frontend has its own deployment
mechanism. See that repo for more information.


See the [LICENSE](LICENSE) for details on permissions and warranties. Please contact
nsidc@nsidc.org for more information.


## Releasing a new verison of the DAT backend

The Data Access Tool relies on the
[data-access-tool-backend](https://github.com/nsidc/data-access-tool-backend),
which is deployed to a VM via this repo's config.

To release a new version of the DAT backend, update the
`DAT_BACKEND_VERSION.txt` with the version of the backend you want to
deploy. This will be the version deployed to all environments except integration
(`latest`-tagged docker images are used) and dev (`main` is checked out and the
docker stack is built from scratch).

## Credit

This content was developed by the National Snow and Ice Data Center with funding from
multiple sources.
