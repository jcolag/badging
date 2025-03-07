#!/bin/sh
name=$(yq -r .issuer.name org.yml | tr '[:upper:]' '[:lower:]' | tr '[:punct:]' '-' | tr '[:space:]' '-' | tr -s '-' | sed 's/-*$//g')
openssl genpkey -algorithm ed25519 -out "private-${name}.pem"
openssl pkey -in "private-${name}.pem" -pubout -out "public-${name}.pem"

## Creating a signature:
# openssl pkeyutl -sign -inkey private-example-issuer.pem -out signature.bin -rawin -in message.bin
## Verifying the signature:
# openssl pkeyutl -verify -pubin -inkey public-example-issuer.pem -rawin -in message.bin -sigfile signature.bin

## Apparently, the following isn't compatible with signing, somehow.
## Probably not worth fixing when OpenSSL has its own solution.
# ssh-keygen -t ed25519 -f "${name}" -C "${*}" -N ''
# ssh-keygen -p -f "${name}"
# ^- Will add a passphrase to the key.

