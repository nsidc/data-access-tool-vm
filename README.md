<p align="center">
  <img alt="NSIDC logo" src="https://nsidc.org/themes/custom/nsidc/logo.svg" width="150" />
</p>

> [!WARNING]
> This VM project currently uses `hermes` as the project name, which is a legacy
> of the original ECS-based ordering backend that served the DAT. It uses
> configurations including secrets from the `hermes` project
> (e.g.,`EARTHDATA_APP_CLIENT_ID`) . Eventually, we may want to update the names
> to reflect `data-access-tool`.


# Data Access Tool VM

NSIDC VM configuration for the Data Access Tool (DAT).

The DAT is composed of:

* [data-access-tool-ui](https://github.com/nsidc/data-access-tool-ui)
* [data-access-tool-backend](https://github.com/nsidc/data-access-tool-backend)


See the [LICENSE](LICENSE) for details on permissions and warranties. Please contact
nsidc@nsidc.org for more information.

## Credit

This content was developed by the National Snow and Ice Data Center with funding from
multiple sources.
