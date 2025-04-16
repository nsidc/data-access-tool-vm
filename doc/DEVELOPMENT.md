## Releasing a new verison of the DAT backend

The Data Access Tool relies on the
[data-access-tool-backend](https://github.com/nsidc/data-access-tool-backend),
which is deployed to a VM via this repo's config.

To release a new version of the DAT backend, update the
`DAT_BACKEND_VERSION.txt` with the version of the backend you want to
deploy. This will be the version deployed to all environments except integration
(`latest`-tagged docker images are used) and dev (`main` is checked out and the
docker stack is built from scratch).
