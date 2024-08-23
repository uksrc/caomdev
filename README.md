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


## Deploying
1. Install self-signed certificates
	- RootCA.crt in browser and command line. See [Ubuntu example](https://ubuntu.com/server/docs/install-a-root-ca-certificate-in-the-trust-store) and [Firefox example](https://docs.vmware.com/en/VMware-Adapter-for-SAP-Landscape-Management/2.1.0/Installation-and-Administration-Guide-for-VLA-Administrators/GUID-0CED691F-79D3-43A4-B90D-CD97650C13A0.html) for linux reference.
	- Domain for this is https://src-data-repo.co.uk
	- Can be changed but you'll have to create your own certificate & root authority, repeat 1 above, update the nginx.conf and replace the rootCA.crt in each service's config folder (so they can trust each other).

2. Install Docker (& docker-compose)  

	>	https://docs.docker.com/get-docker/    
	>	https://docs.docker.com/compose/install/  


3. Clone repository  
	>	https://github.com/uksrc/caomdev  

4. Adjust settings
	See [detail.md](detail.md) for information reagrding identity managment, permissions groups & bearer tokens for requests.

5. Start the postgres db (done separately)

```
docker-compose -f docker-compose-dbase.yml up -d
```

6. Wait for a minute or so to allow the postgres db to start 

7. Start the main services

```
docker-compose up -d
```

8. Stopping the services  

```
docker-compose down
docker-compose -f docker-compose-dbase.yml down
```

## Testing

Each component has a couple of standard 'status' APIs (returns XML):

#### Get the status of the component(s)
>https://<em>\<domain\></em>/<em>\<component\></em>/availability

#### Get a list of available APIs 
>https://<em>\<domain\></em>/<em>\<component\></em>/capabilities

Can be called like this from the command line (or use the URL in a browser)  
```
curl -k https://src-data-repo.co.uk/torkeep/availability
```
These should work for the <em>reg</em>, <em>baldur</em> or <em>torkeep</em> components.


#### List the registry contents  
```
curl -k https://src-data-repo.co.uk/reg/resource-caps

# Should return a list of services that were defined in <em>./config/reg/reg-resource-caps.properties

#First, global services:
ivo://skao.int/reg = https://src-data-repo.co.uk/reg/capabilities  
ivo://skao.int/gms = https://ska-gms.stfc.ac.uk/gms/capabilities  
ivo://skao.int/baldur = https://src-data-repo.co.uk/baldur/capabilities  
```


#### Group permissions as defined in <em>./config/baldur/baldur.properties</em>  
Extra info here - https://github.com/opencadc/storage-inventory/tree/main/baldur  

>curl https://<em>\<domain\></em>/baldur/perms?op=<em>grantType</em>\&ID=<em>identifier</em>
```
> curl https://src-data-repo.co.uk/baldur/perms?op=read\&ID=caom:EMERLIN/

# Should return (if found), details of the group

<?xml version="1.0" encoding="UTF-8"?>
<grant type="ReadGrant">
  <expiryDate>2024-08-02T09:30:20.146</expiryDate>
  <anonymousRead>true</anonymousRead>
</grant>

# assetID pattern needs to conform to caom:{collection}/{observationID}
```

 ⚠️ **Warning:** Be cautious of the pattern used to match, see [baldur.properties](config/baldur/baldur.properties)' <em>\<entry name\></em>.pattern for the regular expression used to match the search term.

<br>
  
#### Database submission & retrieval (torkeep service)  
https://src-data-repo.co.uk/torkeep/ in a browser for a detailed list of available APIs in a more readable fashion than calling <em>../torkeep/capabilities</em>

**Note** A bearer token is required for write and delete requests (shown as "SKA_TOKEN" below), see [details.md](detail.md) for user account & bear token information. 
```
> curl https://src-data-repo.co.uk/torkeep/observations
# Should return the list of groups (collections) defined in baldur.properties

EMERLIN

# Inject some data
> curl -v --header "Content-Type: text/xml" --header "authorization: bearer $SKA_TOKEN" -T test_data.xml https://src-data-repo.co.uk/torkeep/observations/EMERLIN/TS8004_C_001_20190801_avg.ms

# Check what's been stored for a named collection 
> curl https://src-data-repo.co.uk/torkeep/observations/EMERLIN
EMERLIN minimal-observation     2024-08-22T10:56:37.252 md5:f1a40291ce1dd85623a43d0c2b3b3758
EMERLIN TS8004_C_001_20190801_avg.ms    2024-08-22T11:05:31.771 md5:260c09954bcb7494e0ca8255aa3ec743

# Delete an entry
> curl -X DELETE --header "authorization: bearer $SKA_TOKEN" -T test_data.xml https://src-data-repo.co.uk/torkeep/observations/EMERLIN/TS8004_C_001_20190801_avg.ms

```

<br>





