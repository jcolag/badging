# SPDX-FileCopyrightText: 2025 John Colagioia <jcolag@colagioia.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#!/bin/sh
type=rsa
name=$(yq -r .issuer.name org.yml | tr '[:upper:]' '[:lower:]' | tr '[:punct:]' '-' | tr '[:space:]' '-' | tr -s '-' | sed 's/-*$//g')

if [ -n "$1" ]
then
  type="$1"
fi

openssl genpkey -algorithm "$type" -out "private-${name}-${type}.pem"
openssl pkey -in "private-${name}-${type}.pem" -pubout -out "public-${name}-${type}.pem"

## Creating a signature:
# openssl pkeyutl -sign -inkey private-example-issuer.pem -out signature.bin -rawin -in message.bin
## Verifying the signature:
# openssl pkeyutl -verify -pubin -inkey public-example-issuer.pem -rawin -in message.bin -sigfile signature.bin

## Apparently, the following isn't compatible with signing, somehow.
## Probably not worth fixing when OpenSSL has its own solution.
# ssh-keygen -t ed25519 -f "${name}" -C "${*}" -N ''
# ssh-keygen -p -f "${name}"
# ^- Will add a passphrase to the key.

