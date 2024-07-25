Setting up test CAOM DB
========================


Detailed instructions from Pat Dowler


For setting up a CAOM database and storing metadata, there are a few components:

1. the REST api service (torkeep): docker image images.opencadc.org/caom2/torkeep and 0.1.4 is the latest image (tag); the source code and (admittedly minimal) docs are here: https://github.com/opencadc/caom2db/tree/master/torkeep
2. the python caom2 tools are installable from PyPI and source/docs are here: https://github.com/opencadc/caom2tools
3. The blank2caom2 repo template uses the python tools, including a client to the REST api, to create and persist observations
4.  for later, the caom2 TAP service (argus): images.opencadc.org/caom2/argus
and 1.0.9 is the latest image; the source and docs are here: https://github.com/opencadc/caom2service/tree/master/argus; I include it because knowing you'll eventually deploy it means adding schema(s) and accounts to support that as well.

There are a few other details:

You will need a postgresql db with pgsphere and citext extensions; ultimately you will want 3 accounts in that server (I use tapadm with argus for the uws and tapadm pools, and tapuser for the query pool, and you'll need "content account" for torkeep that has full permissions in the caom2 schema); you will also want tap_schema, tap_upload, uws, and caom2 schema created. If you want something developer ready and disposable, you could look here: https://github.com/opencadc/docker-base/tree/master/cadc-postgresql-dev for docker (no published image) as it can do the right setup with a single config file.

To configure torkeep to allow writes, you also need a permissions service and a registry service (not a full one, just a a minimal thing to lookup a resourceID and get the URL to the capabilities. We use:
https://github.com/opencadc/reg/tree/master/reg images.opencadc.org/core/reg as the registry
https://github.com/opencadc/storage-inventory/tree/master/baldur (images.opencadc.org/storage-inventory/baldur for permissions

ll of these are running in what was the mini-srcnet demonstrator (operated by Coral, Franz Kirsten runs these) so you could probably just get some records added to them rather than bringing up your own, or run your own torkeep and make use of the central baldur and reg)
And of course: a way to authenticate, which would be  "get token from SRCNet IAM" and use it to make the calls to torkeep. I'll have to check with Adrian Damian that the minimal token support has been added to the caom2 repository client.

The current reg service is here:
https://spsrc27.iaa.csic.es/reg/capabilities
and the simple config-map style output is:
https://spsrc27.iaa.csic.es/reg/resource-caps
You can think of that output as a canned query on a real registry, but is is actually just a network-accessible config file mapping resourceID to the capabilities endpoint; OpenCADC services mostly know (config or content) the resourceID and need to get the details before calling the service, and this supports that sequence while centrally managing the actual locations (URLs)

Franz Kirsten's test deployment:
https://gitlab.com/fkirsten/opencadc-metadata


# Using the test IAM

In some of our other services we did implement a local testing option  where just authenticating was sufficient to allow writes; it turned out to be more dangerous than valuable so we didn't end up implementing it in other services.
I believe for skaha you need to belong to an IAM group and configure skaha to allow that group... the usage for torkeep isn't much more complicated.
1. create or chose a group in IAM for people who can curate (create/update/delete) metadata in a collection 
2. configure (torkeep.properties) a permissions service: **org.opencadc.torkeep.grantProvider = ivo://skao.int/baldur**
3. ask Franz Kirsten to add a rule for your collection to the config of that service referencing the IAM group
4. that baldur service is part of the Coral mini-srcnet deployment, so to resolve that uri you also need to configure your torkeep service to use the mini-srcnet registry: in cadc-registry.properties: **ca.nrc.cadc.reg.client.RegistryClient.baseURL = https://spsrc27.iaa.csic.es/reg**

The cadc-registry.properties will also include **ivo://ivoa.net/sso#OpenID = https://ska-iam.stfc.ac.uk/** to indicate that is the trusted OpenID provider (to validate auth).

After that, when you request to write, torkeep will lookup and call baldur to see who can write to caom:{collection}/

You could also run your own registry (reg) and permissions (baldur) services if you want a more standalone setup under your control; I run those for my dev environment to use when working on and testing service code locally.

# Database 

Q: When deploying the postgres dev container, I seem to get a postgres instance with a number of schemas defined and nothing else, is the expected behaviour (if the submission of observations creates the tables then OK). With a custom init-content-schemas.sh of:
```
CATALOGS="cadctest"
SCHEMAS="caom2 tap_schema tap_upload uws inventory vospace"
```

Which gives me a cadctest database with the following schemas
```
        List of schemas
    Name    |       Owner
------------+-------------------
 caom2      | cadmin
 inventory  | cadmin
 public     | pg_database_owner
 tap_schema | tapadm
 tap_upload | tapuser
 uws        | tapadm
 vospace    | cadmin
```
When you start up torkeep pointing at that database, the pool will use the cadmin (content admin) account and create all the caom2 tables; the logs and the /torkeep/availability check is good to verify everything is working in that respect the tap_schema and uws tables are owned/managed by the tapadm account and are created/managed by the CAOM TAP service (argus);

Q:
What's the easiest way to check the baldur service? I'm wondering if I can make a quick curl "http://localhost:8080/baldur/perms?OP=write&ID=baldur:TEST"
A:
Using URIs with the cadc scheme is more for data files. In CAOM, observations have (currently internal) URIs of the form caom:{collection}/{observationID} and when you try to write to the torkeep API it will call the grantProvider (baldur) to see who can write to caom:{collection}/  -- a metadata namespace. A config like this in baldur:

CAOM permissions used by torkeep
```
org.opencadc.baldur.entry = CAOM-TEST
CAOM-TEST.pattern = ^caom:TEST/.*
CAOM-TEST.readWriteGroup = {group uri}*
```

would allow the specified group to write (curate metadata) in the TEST collection. You can put rules like this for multiple collections.
You'll need to configure baldur with org.opencadc.baldur.allowAnon = true (necessary because we don't have a way for torkeep to use tokens to make that call; we use x509 certs internally for this kind of thing), then you can check the permissions on a collection with a call like this (example from my dev setup):

```
curl https://haproxy.cadc.dao.nrc.ca/baldur/perms?op=write\&ID=caom:TEST/
<?xml version="1.0" encoding="UTF-8"?>
<grant type="WriteGrant">
  <assetID>caom:TEST/</assetID>
  <expiryDate>2024-07-17T16:28:51.721</expiryDate>
  <groups>
    <groupURI>ivo://cadc.nrc.ca/gms?caom2TestGroupWrite</groupURI>
  </groups>
</grant>
```
that's what torkeep will do.


Q: From catalina.properties org.opencadc.torkeep.caom2.url=jdbc:postgresql://{server}/{database} can be the dev postgres instance I deployed just be used (from cadc-postgresql-dev)? so in my case jdbc:postgresql://localhost:5432/metadata 
A: yeah, that dev postgres container will suffice for any opencadc s/w... most of our devs use it daily; it's not really suitable for anything you actually care about (because I'm not a dba and just wanted the minimal working throw-away server :slightly_smiling_face:). I actually don't use it because I prefer lxd (well, incus these days) for db containers. I don't know exactly how localhost:5432 would look from inside the torkeep container (I don't map container IPs to the host in my dev environment and prefer docker run --add-host ... , but I'm sure there are many ways to do it and make it work). torkeep logs will certainly fail loudly if it can't connect to the db server.

Q: How does torkeep resolve the registry service? does it just assume that the service is running on the same host under ../reg ? I can see how torkeep resolves the gms (via the registry entry) but I'm assuming there must be a setting somewhere that points to the deployed registry itself.
A: the registry base URL is configured in config/cadc-registry.properties (https://github.com/opencadc/reg/blob/main/reg/README.md)
minimal config for you (assuming using the SRCnet IAM service) would be something like:
```
# configure RegistryClient bootstrap
ca.nrc.cadc.reg.client.RegistryClient.baseURL = https://haproxy.cadc.dao.nrc.ca/reg

## SRC IAM prototype 
ivo://ivoa.net/sso#OpenID = https://ska-iam.stfc.ac.uk/                                                                           
ivo://ivoa.net/std/GMS#search-1.0 = ivo://skao.int/gms
```
this is from my test config - you'll need to change the registry baseURL. The other two settings cause torkeep to trust those AAI related services and thus be willing to send oidc tokens to them for validation and group checks.
That skao GMS service is deployed at:
```
ivo://skao.int/gms = https://ska-gms.stfc.ac.uk/gms/capabilities
```
so you'd need that in your reg config to resolve it.

Further after looking at Franz's repo, https://gitlab.com/fkirsten/opencadc-metadata/-/blob/main/config/cadc-registry.properties?ref_type=heads needs mapping/mounting to the config folder in the torkeep container so that the local registry can be found (update the absolute URL as required).

Q: Unable to resolve the StandardIdentityManager when running calling .../torkeep/capabilities
A: Check logs 
```
docker logs  -f {container}
```

...turns out the other components don't seem to be reolved..

When I launch containers, I use this kind of approach:
```
CMD="docker run --rm --user tomcat:tomcat \
        --network=$DOCKER_NET --ip=$DOCKER_STATIC_IP \
        --add-host $HAP:$HAPIP \
        --add-host $PG:$PGIP \
        --volume=$(pwd)/config:/config:ro \
        --name $SELF $IMG"
```
where HAP:HAPIP is the hostname and IP addr of my haproxy container, PG:PGIP is the database container; that adds them to /etc/hosts in the container
The DOCKER_NET and DOCKER_STATIC_IP is my custom network and the IP of the container: I get the latter by extracting it from the haproxy configuration so it's consistent with how haproxy will direct traffic to the container. haproxy does all the https (termination, client cert support, etc) and proxies calls to {container ip}:8080
That might be overkill for your setup; I have about 5-10 PG instances and 5-20 service containers running at any one time so it was worth the effort for me... but maybe some ideas. Also, it's subtle but if you use self-signed cert (eg for a front end proxy) you can add the CA to all the containers (one or more files in config/cacerts) so that calls from one container to another will be able to verify the server cert. The container startup automatically adds any files in there to the local trust store so they are known to java/tomcat and other tools that use openssl, eg curl, which is installed in all containers so you can exec in there and manually check what's happening network-wise

Q: CADC's harbor image repo query (for image versions etc)
A: yeah, we run a harbor registry at images.opencadc.org... unfortunately the UI requires login (don't know why) but the images are all anon readable.
```
images.opencadc.org/core/reg
images.opencadc.org/caom2/torkeep
images.opencadc.org/storage-inventory/baldur
```
we don't publish the dev images like cadc-postgresql-dev
the harbor API let's you query for all the tags with a URL of this form:
```
https://images.opencadc.org/api/v2.0/projects/${PROJ}/repositories/${IMG}/artifacts
```
eg for core/reg:
```
curl https://images.opencadc.org/api/v2.0/projects/core/repositories/reg/artifacts 
```
outputs json; I use jq to extract versions from that (will post my useful bash script below; I should put it into github somewhere)
```
script:
#!/bin/bash

PROJ=$1
IMG=$2
SHA=$3

if [ -z "$PROJ" ]; then
    echo "** projects"
    curl -s https://images.opencadc.org/api/v2.0/projects | jq '[.[].name] | sort'
    echo "usage: $0 [<project> [<image> [--sha]]]"
    exit 0
fi

if [ -z "$IMG" ]; then
    echo
    echo "** images"
    URL=https://images.opencadc.org/api/v2.0/projects/${PROJ}/repositories
    echo $URL
    curl -s $URL | jq '[.[].name] | sort'
    echo "usage: $0 [<project> [<image> [--sha]]]"
    exit 0
fi

echo
echo "** image versions"
URL=https://images.opencadc.org/api/v2.0/projects/${PROJ}/repositories/${IMG}/artifacts
echo $URL
if [ -z "$SHA" ]; then
    
    curl -s $URL | jq '[.[].tags | select (. != null) | .[].name] | sort'
elif [ "$SHA" == "--sha" ]; then
    curl -s $URL | jq '.[]| [.digest,.tags[].name] '
fi
```