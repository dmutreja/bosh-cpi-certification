## BOSH CPI CERTIFICATION

This repository contains additional tests above and beyond unit and integration
tests. This is meant to complement the existing tests, not to replace.

### Certification Pipelines

#### [vCloud](https://bosh-cpi-tmp.ci.cf-app.com/teams/pivotal/pipelines/certify-vcloud)

* setting the vcloud certification pipeline

  ```bash
  fly -t cpi-tmp set-pipeline -p certify-vcloud -c ~/workspace/bosh-cpi-certification/vcloud/pipeline.yml --load-vars-from <( lpass show --note YOUR_CERTIFICATION_SECRETS)
  fly -t cpi-tmp expose-pipeline -p certify-vcloud
  ```

#### [AWS](https://bosh-cpi-tmp.ci.cf-app.com/teams/pivotal/pipelines/certify-aws)

* setting the vcloud certification pipeline

  ```bash
  fly -t cpi-tmp set-pipeline -p certify-aws -c ~/workspace/bosh-cpi-certification/aws/pipeline.yml --load-vars-from <( lpass show --note YOUR_CERTIFICATION_SECRETS)
  fly -t cpi-tmp expose-pipeline -p certify-aws
  ```


# bosh CPI certification

The bosh CPI certification is intended to combine scripts and pipelines for certifying bosh CPI, bosh releases and stemcells. This will provide more confidence a fully working director is able to be successfuly deployed with all stemcell flavors and upgraded from not so old, but also not so new versions.

* What are we testing?
	- bosh CPI releases.
* Why are we testing?
	- To provide more confidence new releases of stemcells, bosh and CPIs work together properly.
* When will the pipeline run?
	- Whenever any of the following are released: (`trigger: true`)
		1. [bosh-release](https://bosh.io/releases/github.com/cloudfoundry/bosh?all=1)
		2. bosh-\<iaas\>-cpi-release
		3. [stemcell](https://bosh.io/stemcells)
        4. every day at midnight. why? why not? Concourse will do the work ;)
* How are we testing?
	1. We run [BATs](https://github.com/cloudfoundry/bosh-acceptance-tests) for every flavor of stemcells (ubuntu-trusty and centos-7).
	2. A bosh director upgrade test from a previous version family stemcell (e.g. 3363.x to 3421.latest).
	3. Specific IaaS end-2-end tests, if necessary.


## BATs
0. Setup infrastructure environment from scratch, we use [Terraform resource](https://github.com/ljfranklin/terraform-resource) when and wherever we can. It works beautifully.
0. Deploy bosh director with latest bosh-release, iaas specific cpi-release and stemcell
0. Run BATs
0. Teardown director
0. Teardown infrasctructure environment

## Upgrade test
0. Setup infrastructure environment from scratch, we use [Terraform resource](https://github.com/ljfranklin/terraform-resource) when and wherever we can. It works beautifully.
0. Deploy bosh director with old bosh-release (255.4), iaas specific cpi-release (X) and stemcell (3363.x)
0. Deploy certification-release
0. Redeploy bosh director with latest bosh-release, iaas specific cpi-release and stemcell
0. Redeploy certification-release with `--recreate`
0. Teardown director
0. Teardown infrasctructure environment

## End-2-end test
TODO

# Setting up your own CPI certification pipeline

Setup folder structure: 
```
export iaas_certification=<iaas>
cp -r fake "${iaas_certification}"
replace <fake> for "${iaas_certification}"
```
The folder structure will look somethings like this:
```
.
├── iaas
    ├── bats
    |   └── bats-spec.yml
    ├── certification
    |   └── cloud-config-ops.yml
    ├── ops
    |   └── custom-cpi-release.yml
    └── pipeline.yml
```


# bosh CPIs
* [vSphere](https://github.com/cloudfoundry-incubator/bosh-vsphere-cpi-release)
* [AWS](https://github.com/cloudfoundry-incubator/bosh-aws-cpi-release)
* [GCP](https://github.com/cloudfoundry-incubator/bosh-google-cpi-release)
* [OpenStack](https://github.com/cloudfoundry-incubator/bosh-openstack-cpi-release)
* [Azure](https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release)
* [vCloud](https://github.com/cloudfoundry-incubator/bosh-vcloud-cpi-release)

Others:
* [VirtualBox](https://github.com/cppforlife/bosh-virtualbox-cpi-release)
* [Docker](https://github.com/cppforlife/bosh-docker-cpi-release)
* [Warden](https://github.com/cppforlife/bosh-warden-cpi-release)
