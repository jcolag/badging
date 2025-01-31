# frozen_string_literal: true

require 'chunky_png'
require 'json'
require 'optparse'
require 'ostruct'

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
      opts.on('-m', '--metadata file.json', 'The file containing the badge metadata, in JSON') do |m|
        options.metadata = m
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

def embed_metadata(image_path, metadata_path, output_path)
  image = ChunkyPNG::Image.from_file image_path
  metadata = JSON.parse File.read(metadata_path)

  validate_metadata metadata

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
