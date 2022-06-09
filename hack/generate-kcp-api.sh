#!/bin/sh

set -e

if ! which yq; then
  echo "yq required"
  exit 1
fi

if ! which kubectl-kcp; then
  echo "kubectl-kcp required on path"
  echo "you can install it with running:"
  echo "    $ git clone https://github.com/kcp-dev/kcp && cd kcp && make install"
  exit 1
fi

THIS_DIR="$(dirname "$(realpath "$0")")"
CRD_DIR="$( realpath ${THIS_DIR}/../config/crd/bases)"
KCP_API_DIR="$( realpath ${THIS_DIR}/../config/kcp)"

KCP_API_SCHEMA_FILE_CURRENT="${KCP_API_DIR}/apiresourceschema_spi.yaml"
KCP_API_SCHEMA_FILE_NEW="${KCP_API_DIR}/apiresourceschema_spi.yaml_new"
cat << EOF > ${KCP_API_SCHEMA_FILE_NEW}
# This file is generated from CRDs by ./hack/generate-kcp-api.sh script.
# Please do not modify!

EOF

# APIResourceSchema is immutable so when we want to update something, we actually have to create new version.
# Version is defined by this prefix, which is taken from date. This will allow us to do new version each minute, which
# should be hopefully enough granularity :)
PREFIX=$( TZ="Etc/UTC" date +%Y%m%d%H%M )

I=0
for CRD in $( ls ${CRD_DIR} ); do
  kubectl-kcp crd snapshot -f "${CRD_DIR}/${CRD}" --prefix v${PREFIX} >> ${KCP_API_SCHEMA_FILE_NEW}
done

# If there are some changes in new generated file, we replace old one. Otherwise just remove new file.
# The regex is there to ignore name change, because we're updating date there so it is expected to change.
# Ignored line looks like this:
# '  name: 202206091540.spiaccesstokendataupdates.appstudio.redhat.com'
if ! diff -I '^  name: v[0-9]\{12\}\..*\.appstudio\.redhat\.com$' ${KCP_API_SCHEMA_FILE_CURRENT} ${KCP_API_SCHEMA_FILE_NEW} > /dev/null; then
  mv ${KCP_API_SCHEMA_FILE_NEW} ${KCP_API_SCHEMA_FILE_CURRENT}
  echo "updated KCP APIResourceSchema for SPI saved at '${KCP_API_SCHEMA_FILE_CURRENT}'"
else
  echo "no changes in KCP API"
  rm ${KCP_API_SCHEMA_FILE_NEW}
fi


# now create APIExport and link all created APIResourceSchemas there
KCP_API_EXPORT_FILE="${KCP_API_DIR}/apiexport_spi.yaml"
cat << EOF > ${KCP_API_EXPORT_FILE}
# This file is generated from CRDs by ./hack/generate-kcp-api.sh script.
# Please do not modify!

apiVersion: apis.kcp.dev/v1alpha1
kind: APIExport
metadata:
  name: spi
spec:
  latestResourceSchemas:
EOF

I=0
for SCHEMA in $( yq '.metadata.name' ${KCP_API_SCHEMA_FILE_CURRENT} ); do
  # because we have multiple yamls in single file, yq gives us --- separators in the output.
  # Also last line is null, because kubectl-kcp generates end of file with ---
  if [ "$SCHEMA" = "---" ] || [ "$SCHEMA" = "null" ]; then
    continue
  fi

  I=${I} SCHEMA=${SCHEMA} yq -i '.spec.latestResourceSchemas[env(I)] = env(SCHEMA)' ${KCP_API_EXPORT_FILE}
  I=$((I + 1))
done
