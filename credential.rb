# frozen_string_literal: true

# SPDX-FileCopyrightText: 2025 John Colagioia <jcolag@colagioia.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

require 'base64'
require 'chunky_png'
require 'ed25519'
require 'json'
require 'json/ld'
require 'openssl'
require 'optparse'
require 'ostruct'
require 'yaml'

# Horrifying Monkey-Patch To Allow Parsing of Dates, Part 1
# See https://github.com/ruby/psych/issues/262
class UnparsedDateMonkeyPatch
  def strptime(strscalar, _fmt, _calendar)
    strscalar # Don't parse the input.
  end
end

# Horrifying Monkey-Patch To Allow Parsing of Dates, Part 2
# See https://github.com/ruby/psych/issues/262
module YAML
  class ClassLoader
    # Nested class to support monkey-patch
    class Restricted
      def find(klassname)
        return UnparsedDateMonkeyPatch.new if klassname == 'Date'

        super
      end
    end
  end
end

# Class to process command-line arguments
class Options
  def self.parse(args)
    options = OpenStruct.new
    options.image = nil
    options.metadata = nil
    options.badge = nil

    opt_parser = OptionParser.new do |opts|
      opts.banner = 'Usage:  credential.rb [options]'
      opts.separator ''
      opts.separator 'Specific options:'
      opts.on '-b', '--badge file.png', 'The name for the output badge' do |b|
        options.badge = b
      end
      opts.on '-i', '--image file.png', 'The badge image' do |i|
        options.image = i
      end
      opts.on '-o', '--organization org.yml', 'The file containing the organization metadata, in YAML' do |o|
        options.organization = o
      end
      opts.on '-r', '--recipient badge.yml', 'The file containing the badge and recipient metadata, in YAML' do |r|
        options.recipient = r
      end
    end

    opt_parser.parse!(args)
    options
  end
end

def base_metadata
  {
    '@context': [
      'https://www.w3.org/ns/credentials/v2',
      'https://purl.imsglobal.org/spec/ob/v3p0/context-3.0.3.json',
      'https://purl.imsglobal.org/spec/ob/v3p0/extensions.json'
    ],
    'type': %w[
      VerifiableCredential
      OpenBadgeCredential
    ],
    'credentialSchema': [
      {
        'id': 'https://purl.imsglobal.org/spec/ob/v3p0/schema/json/ob_v3p0_achievementcredential_schema.json',
        'type': '1EdTechJsonSchemaValidator2019'
      }
    ]
  }
end

def create_proof(metadata, signature)
  metadata['proof'] = {
    'type': 'DataIntegrityProof',
    'created': Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z'),
    'verificationMethod': metadata['issuer']['id'],
    'cryptosuite': 'eddsa-rdfc-2022',
    'proofPurpose': 'assertionMethod',
    'proofValue': signature
  }
  metadata
end

def get_key(metadata)
  keylines = File.binread(metadata['issuer']['private_key']).split "\n"
  asn1 = OpenSSL::ASN1.decode Base64.decode64 keylines[1]
  private_key_octet = asn1.value[2]
  inner_der = private_key_octet.value
  seed = inner_der[2, 32]

  Ed25519::SigningKey.new seed
end

def add_proof(metadata)
  key = get_key metadata

  metadata['issuer'].delete 'private_key'
  signature = key.sign File.open('message.bin', 'r:UTF-8', &:read)
  create_proof metadata, signature
  metadata
end

def embed_metadata(image_path, organization_path, recipient_path, output_path)
  image = ChunkyPNG::Image.from_file image_path
  org = YAML.load_file organization_path
  recip = YAML.load_file recipient_path
  metadata = base_metadata

  metadata = metadata.merge org
  metadata = add_proof metadata
  metadata = metadata.merge recip
  metadata_json = JSON.generate metadata

  image.metadata['openbadgecredential'] = metadata_json
  image.save output_path
end

def validate_metadata(metadata)
  required_fields = %w[id issuer validFrom name proof]
  missing_fields = required_fields - metadata.keys
  raise "Metadata missing required fields: #{missing_fields.join(', ')}" unless missing_fields.empty?
end

options = Options.parse ARGV

if options.image.nil?
  puts 'This program requires the --image option to specify the badge image.'
  return
end

if options.organization.nil?
  puts 'This program requires the --organization option to specify the file with'
  puts 'your organizational metadata.'
  return
end

if options.recipient.nil?
  puts 'This program requires the --recipient option to specify the file with'
  puts 'the badge and recipient metadata.'
  return
end

options.badge = "final-#{options.image}" if options.badge.nil?

embed_metadata options.image, options.organization, options.recipient, options.badge
