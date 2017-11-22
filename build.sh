#!/bin/bash

set -e

if [ "x${BUILD_PLATFORM}" == "x" ]; then
    echo "!!! BUILD_PLATFORM not set, exiting."
    exit 2
fi

OMNIBUS_COMMIT=$(git rev-parse HEAD)

if [ "$(git describe --tags --exact-match "$OMNIBUS_COMMIT")" ]; then
    TAGS=$(git tag -l --points-at HEAD)
    TAG=$(echo "$TAGS" | sort -r | head -1)

    echo "======================== Found tags $TAGS on commit $OMNIBUS_COMMIT"
    echo "======================== Selected $TAG as latest tag"

    SENSU_VERSION=$(echo "$TAG" | awk -F'-' '{print $1}' | sed 's/v//g')
    BUILD_NUMBER=$(echo "$TAG" | awk -F'-' '{print $2}')
    PROJECT_REVISION=$TAG

    export SENSU_VERSION BUILD_NUMBER PROJECT_REVISION

    echo "======================== Building ${SENSU_VERSION}-${BUILD_NUMBER} on ${BUILD_PLATFORM}"

    if [[ "x$TRAVIS_WAIT" == "x" ]] ; then
        bundle exec rake kitchen:default-"$BUILD_PLATFORM"
    else
        source "$TRAVIS_BUILD_DIR/.travis/functions.sh"
        travis_wait "$TRAVIS_WAIT" bundle exec rake kitchen:default-"$BUILD_PLATFORM"
    fi
else
    echo "!!! Commit ${OMNIBUS_COMMIT} is not tagged, exiting."
    exit 2
fi
