#!/bin/sh

git submodule add https://github.com/keycloak/keycloak.git keycloak
git submodule add https://github.com/jboss-dockerfiles/keycloak.git keycloak-docker

cd keycloak
git checkout 3.3.x
cd ..
