# frozen_string_literal: true

require 'chunky_png'
require 'json'
require 'optparse'
require 'ostruct'
require 'yaml'

# Horrifying Monkey-Patch To Allow Parsing of Dates, Part 1
# See https://github.com/ruby/psych/issues/262
class UnparsedDateMonkeyPatch
  def strptime(strscalar, _fmt, _calendar)
    strscalar #-- return input untouched, don't parse nothing.
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
      opts.on('-b', '--badge file.png', 'The name for the output badge') do |b|
        options.badge = b
      end
      opts.on('-i', '--image file.png', 'The badge image') do |i|
        options.image = i
      end
      opts.on('-o', '--organization org.yml', 'The file containing the organization metadata, in YAML') do |o|
        options.organization = o
      end
      opts.on('-r', '--recipient badge.yml', 'The file containing the badge and recipient metadata, in YAML') do |r|
        options.recipient = r
      end
    end

    opt_parser.parse!(args)
    options
  end
end

def embed_metadata(image_path, organization_path, recipient_path, output_path)
  image = ChunkyPNG::Image.from_file image_path
  org = YAML.load_file organization_path
  recip = YAML.load_file recipient_path
  metadata = org.merge recip
  metadata_json = JSON.pretty_generate metadata

  image.metadata['openbadgecredential'] = metadata_json
  image.save output_path
  puts "Badge with metadata saved to: #{output_path}"
end

def validate_metadata(metadata)
  required_fields = %w[@context id type issuer validFrom name credentialSchema proof]
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
