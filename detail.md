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