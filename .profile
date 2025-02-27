# If env exist, assume a base64 encoded compressed tarball, and uncompress it

if [ ! -z "${HOMEARCHIVE}" ]; then
    cd ${HOME}
    echo -n "${HOMEARCHIVE}" | base64 -d | tar -xzf -
fi

if [ ! -z "${HOMEARCHIVEWK}" ]; then
    cd ${HOME}
    echo -n "${HOMEARCHIVEWK}" | base64 -d | tar -xzf -
fi