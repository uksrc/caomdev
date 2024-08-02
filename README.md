 caomdev
 =======

Fire up a local development CAOM db instance. This will only create a local instance of the database with the REST API that the https://github.com/uksrc/emerlin2caom can talk to. There is some [background detail](detail.md) of the services that need to be set up.

## Components

### Postgres database
A built version of this has been deployed to docker hub for convience, image can be changed if an update is required [stephenlloyd/uksrc:cadc-postgresql-dev](https://hub.docker.com/layers/stephenlloyd/uksrc/cadc-postgresql-dev/images/sha256-973f6a1a5bdfa9d9b8740a4c9088c38e8a0f78b09f652fa3c14a07c905ff30df?context=repo). 
Intended to be a test database only.

CADC's repository https://github.com/opencadc/docker-base/tree/main/cadc-postgresql-dev
- build an updated version
- push to docker hub (or equivalent)
- update docker-compose-dbase.yml

### CADC components
Several components that have been developed by OpenCADC are used in this deployment:
- [Registry - service discoverability](https://github.com/opencadc/reg/tree/main/reg)
- [Baldur - group managment](https://github.com/opencadc/storage-inventory/tree/main/baldur)
- [Torkeep - API access to database](https://github.com/opencadc/caom2db/tree/main/torkeep)


## Using

1. Install self-signed certificates
	- RootCA.crt in browser and command line TODO - explanation or link
	- Domain for this is https://src-data-repo.co.uk
	- Can be changed but you'll have to create your own, repeat 1 above, update the nginx.conf and replace the rootCA.crt in each service's config folder (so they can trust each other).
<br>
<br>
2. Install Docker (& docker-compose)
<br>
<br>
3. Clone repository
<br>
<br>
4. Start the postgres db (done separately)<br>
	<em>docker-compose -f docker-compose-dbase.yml up -d</em>
<br>
5. Wait for a minute or so to allow the postgres db to start 
<br>
<br>
6. Start the main services <br>
    <em>docker-compose up -d</em>
<br>
<br>