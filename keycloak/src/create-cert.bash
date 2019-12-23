#!/usr/bin/env bash

#
# this script updates the server key in
# /keycloak/standalone/configuration/application.keystore
# which is used by keycloak
#
#
HOSTNAME=mwohlfkeycloak.westeurope.azurecontainer.io


# run certbot to download cert from letsencrypt
certbot certonly --webroot -w /keycloak/welcome-content \
     -d ${HOSTNAME} \
     --non-interactive --agree-tos -m michael@wohlfart.net

# IMPORTANT NOTES:
#  - Congratulations! Your certificate and chain have been saved at:
#    /etc/letsencrypt/live/mwohlfkeycloak.westeurope.azurecontainer.io/fullchain.pem
#    Your key file has been saved at:
#    /etc/letsencrypt/live/mwohlfkeycloak.westeurope.azurecontainer.io/privkey.pem
#    Your cert will expire on 2019-06-21. To obtain a new or tweaked
#    version of this certificate in the future, simply run certbot
#    again. To non-interactively renew *all* of your certificates, run
#    "certbot renew"
#  - Your account credentials have been saved in your Certbot
#    configuration directory at /etc/letsencrypt. You should make a
#    secure backup of this folder now. This configuration directory will
#    also contain certificates and private keys obtained by Certbot so
#    making regular backups of this folder is ideal.
#  - If you like Certbot, please consider supporting our work

# extract the cert from the letsencrypt config
openssl pkcs12 -export \
     -in /etc/letsencrypt/live/${HOSTNAME}/fullchain.pem \
     -out /etc/letsencrypt/live/keystore.pkcs12 \
     -inkey /etc/letsencrypt/live/${HOSTNAME}/privkey.pem \
     -name "server" \
     -passout pass:password

# update the keycloak cert
keytool -delete \
     -keystore /keycloak/standalone/configuration/application.keystore \
     -alias 'server' \
     -storepass password

keytool -importkeystore \
     -srckeystore /etc/letsencrypt/live/keystore.pkcs12 \
     -srcstoretype PKCS12 \
     -srcstorepass password \
     -destkeystore /keycloak/standalone/configuration/application.keystore \
     -deststorepass password

# expose the cert for download and include in the next docker image
# cp /keycloak/standalone/configuration/application.keystore /keycloak/welcome-content
# wget --no-check-certificate http://mwohlfkeycloak.westeurope.azurecontainer.io/application.keystore
# keytool -list -v -keystore /keycloak/standalone/configuration/application.keystore -storepass password
