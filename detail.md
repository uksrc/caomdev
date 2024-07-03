Setting up test CAOM DB
========================


detailed instructions from Pat Dowler


for setting up a CAOM database and storing metadata, there are a few components:
the REST api service (torkeep): docker image images.opencadc.org/caom2/torkeep and 0.1.4 is the latest image (tag); the source code and (admittedly minimal) docs are here: https://github.com/opencadc/caom2db/tree/master/torkeep
the python caom2 tools are installable from PyPI and source/docs are here: https://github.com/opencadc/caom2tools
The blank2caom2 repo template uses the python tools, including a client to the REST api, to create and persist observations
for later, the caom2 TAP service (argus): images.opencadc.org/caom2/argus
and 1.0.9 is the latest image; the source and docs are here: https://github.com/opencadc/caom2service/tree/master/argus; I include it because knowing you'll eventually deploy it means adding schema(s) and accounts to support that as well.
There are a few other details:
You will need a postgresql db with pgsphere and citext extensions; ultimately you will want 3 accounts in that server (I use tapadm with argus for the uws and tapadm pools, and tapuser for the query pool, and you'll need "content account" for torkeep that has full permissions in the caom2 schema); you will also want tap_schema, tap_upload, uws, and caom2 schema created. If you want something developer ready and disposable, you could look here: https://github.com/opencadc/docker-base/tree/master/cadc-postgresql-dev for docker (no published image) as it can do the right setup with a single config file.
To configure torkeep to allow writes, you also need a permissions service and a registry service (not a full one, just a a minimal thing to lookup a resourceID and get the URL to the capabilities. We use
https://github.com/opencadc/reg/tree/master/reg images.opencadc.org/core/reg as the registry
https://github.com/opencadc/storage-inventory/tree/master/baldur (images.opencadc.org/storage-inventory/baldur for permissions
All of these are running in what was the mini-srcnet demonstrator (operated by Coral,
@Franz Kirsten
runs these) so you could probably just get some records added to them rather than bringing up your own, or run your own torkeep and make use of the central baldur and reg)
And of course: a way to authenticate, which would be  "get token from SRCNet IAM" and use it to make the calls to torkeep. I'll have to check with
@Adrian Damian
that the minimal token support has been added to the caom2 repository client.


The current reg service is here:
https://spsrc27.iaa.csic.es/reg/capabilities
and the simple config-map style output is:
https://spsrc27.iaa.csic.es/reg/resource-caps
You can think of that output as a canned query on a real registry, but is is actually just a network-accessible config file mapping resourceID to the capabilities endpoint; OpenCADC services mostly know (config or content) the resourceID and need to get the details before calling the service, and this supports that sequence while centrally managing the actual locations (URLs)