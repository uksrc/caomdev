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

