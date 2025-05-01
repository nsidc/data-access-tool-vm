## Development

A development VM can be brought up with:

```
vagrant nsidc up --env=dev
```

Then, ssh to the machine and start developing!

The `data-access-tool-backend` project is checked out to
`/opt/deploy/data-access-tool-backend`.

The `dat-backend` conda environment should be present and will contain the
dependencies specified in the `data-access-tool-backend`'s `environment.yml`.

See the
[data-access-tool-backend](https://github.com/nsidc/data-access-tool-backend)
documentation for more information for developing on a dev VM at NSIDC.


## Releasing a new verison of the DAT backend

The Data Access Tool relies on the
[data-access-tool-backend](https://github.com/nsidc/data-access-tool-backend),
which is deployed to a VM defined by this repo's config.


The [garrison](https://bitbucket.org/nsidc/garrison) deployment system for NSIDC
applications is used for deploying the `data-access-tool-backend` to
non-development environments.

The [jenkins-cd](http://ci.jenkins-cd.apps.int.nsidc.org:8080) Jenkins VM
provides a mechanism for doing garrison deployments of the
`data-access-tool-backend` to integration and QA.

The [Deploy Project with
Garrison](https://ci.jenkins-ops-2022.apps.int.nsidc.org/job/Deploy_Project_with_Garrison/)
job defined in the Ops Jenkins is used by Ops to deploy to staging and
production.

## Environment variables and secrets

Secrets and runtime configuration values are provided as environemnt variables
on provisioned VMs.

An ERB template for these environment variables can be found in
[../puppet/templates/dat.erb](../puppet/templates/dat.erb).

The template gets rendered during provisioning. Secret values are fetched from
NSIDC's vault instance.

The rendered envvar file gets placed in `/etc/profile.d/envvars.sh`.

## Logs

Application logs are stored in `/home/vagrant/logs/` on VMs. These logs are
rotated to NFS (`/share/logs/data_access_tool/{environment}`) for long-term
storage on a weekly basis.

The
[../puppet/templates/logrotate_server.erb](../puppet/templates/logrotate_server.erb)
template is repsonsible for setting up `logrotate` to do the rotation from the
VM's local disk to NFS. This template gets rendered to
`/etc/logrotate.d/server`.

Logrotation can be manually triggered via:

```
sudo logrotate -f /etc/logrotate.d/server
```

To learn more about the DAT application logs, see the
[data-access-tool-backend](https://github.com/nsidc/data-access-tool-backend)
documentation.
