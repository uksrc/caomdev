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
	- RootCA.crt in browser and command line
	- Domain for this is https://src-data-repo.co.uk
	- Can be changed but you'll have to create your own, repeat 1 above, update the nginx.conf and replace the rootCA.crt in each service's config folder (so they can trust each other).
<br>
<br>
2. Install Docker (& docker-compose)  
	https://docs.docker.com/get-docker/  
	https://docs.docker.com/compose/install/
<br>

3. Clone repository  
	https://github.com/uksrc/caomdev
<br>
<br>
4. Start the postgres db (done separately)<br>
	```
	docker-compose -f docker-compose-dbase.yml up -d
	```

5. Wait for a minute or so to allow the postgres db to start 
<br>
<br>
6. Start the main services <br>
	```
    ./start-services.sh
	```

7. Stopping the services  
	```
	docker-compose down
	docker-compose -f docker-compose-dbase.yml down
	```

### Testing

Each component has a couple of standard 'status' APIs (returns XML):

Get the status of the component  
https://<em>\<domain\></em>/<em>\<component\></em>/availability

Get a list of available APIs <br>
	https://<em>\<domain\></em>/<em>\<component\></em>/capabilities

Can be called like this from the command line (or from the browser)  
```
curl -k https://src-data-repo.co.uk/torkeep/availability
```
These should work for <em>reg</em>, <em>baldur</em> or <em>torkeep</em>.


List the **registry contents**  
```
curl -k https://src-data-repo.co.uk/reg/resource-caps
```
Shoud return a list of services that were defined in <em>./config/reg/reg-resource-caps.properties</em>
```
#First, global services:
ivo://skao.int/reg = https://src-data-repo.co.uk/reg/capabilities  
ivo://skao.int/gms = https://ska-gms.stfc.ac.uk/gms/capabilities  
ivo://skao.int/baldur = https://src-data-repo.co.uk/baldur/capabilities  

...
```

**Group permissions** as defined in <em>./config/baldur/baldur.properties</em>  
Extra info here - https://github.com/opencadc/storage-inventory/tree/main/baldur  

curl https://<em>\<domain\></em>/baldur/perms?op=<em>grantType</em>\&ID=<em>identifier</em>
```
curl https://src-data-repo.co.uk/baldur/perms?op=read\&ID=caom:EMERLIN/
```

Should return (if found), details of the group
```
<?xml version="1.0" encoding="UTF-8"?>
<grant type="ReadGrant">
  <assetID>caom:EMERLIN/</assetID>
  <expiryDate>2024-08-02T09:30:20.146</expiryDate>
  <anonymousRead>true</anonymousRead>
</grant>

# assetID pattern needs to conform to caom:{collection}/{observationID}
```

 ⚠️ **Warning:** Be cautious of the pattern used to match, see <em>baldur.properties</em>' **EMERLIN.pattern** for the regular expression used to match the search term.


  
**Database submission & retrieval** (torkeep service)  
https://src-data-repo.co.uk/torkeep/ in a browser for a detailed list of available APIs in a more readable fashion than calling <em>../torkeep/capabilities</em>

A call to observations returns the available groups
```
> curl https://src-data-repo.co.uk/torkeep/observations
test
EMERLIN
```


### Bearer Token for API calls using group permissions
https://confluence.skatelescope.org/display/SRCSC/RED-10+Using+oidc-agent+to+authenticate+to+OpenCADC+services
```
curl -SsL --header "authorization: bearer $SKA_TOKEN"  https://src-data-repo.co.uk/torkeep/observations
```


#### Franz Kirsten's Repo (for reference)
https://gitlab.com/users/fkirsten/projects


### Certs and command line custom domain
As we're currently using a custom domain name, we need to allow the browser to authenticate our own tickets.
https://docs.vmware.com/en/VMware-Adapter-for-SAP-Landscape-Management/2.1.0/Installation-and-Administration-Guide-for-VLA-Administrators/GUID-0CED691F-79D3-43A4-B90D-CD97650C13A0.html

Also, we can do this for command line calls such as curl requests
```
cp rootCa and tls.crt to /usr/local/share/ca-certificates/

sudo update-ca-certificates
```

The domain will need to be added to the "hosts" file

Linux:
```
>nano /etc/hosts
```
There will be an entry(entries) such as:
```
127.0.0.1 localhost
```
Add another:
```
127.0.0.1 src-data-repo.co.uk
```
Should hopefully work immediately.

I’ve never done it on Mac so I just googled this https://www.nexcess.net/help/how-to-find-the-hosts-file-on-my-mac/  

On Windows it’s <em>C:\Windows\System32\drivers\etc\hosts</em>


## Usage
```
# Don't forget to get a new token (1 hour expiration)
export SKA_TOKEN=$(oidc-token example-client)

# Make sure observationID and collection are the same in the file as used in the curl request.

# PUT a new entry
curl -v --header "Content-Type: text/xml" --header "authorization: bearer $SKA_TOKEN" -T test_data.xml https://src-data-repo.co.uk/torkeep/observations/EMERLIN/TS8004_C_001_20190801_avg.ms

# Read the observations under a named collection, read operations shouldn't need the SKA_TOKEN whilst set to anon = true in the baldur.properties. 
curl -X GET --header 'Accept: text/tab-separated-values' 'https://src-data-repo.co.uk/torkeep/observations/EMERLIN'

# Delete a named entry
curl -X DELETE --header "authorization: bearer $SKA_TOKEN" https://src-data-repo.co.uk/torkeep/observations/EMERLIN/TS8004_C_001_20190801_avg.ms
```

### Notes
<em>start-services.sh</em> has to be used to populate HOST_IP required by the docker-compose file, rather than calling <em>docker-compose up</em> directly. This value is used by the containers to allow access to the custom domain and will allow access via the reverse proxy. It's basically the IP address of the host machine from the perspective of the docker containers.


