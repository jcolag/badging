# frozen_string_literal: true

require 'base64'
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
      opts.on('-i', '--image file.png', 'The badge image') do |i|
        options.image = i
      end
      opts.on('-m', '--metadata file.json', 'The file containing the badge metadata, in JSON') do |m|
        options.metadata = m
      end
      opts.on('-b', '--badge file.png', 'The name for the output badge') do |b|
        options.badge = b
      end
    end

    opt_parser.parse!(args)
    options
  end
end

def embed_metadata(image_path, metadata_path, output_path)
  image_data = File.read image_path, mode: 'rb'
  metadata = JSON.parse File.read(metadata_path)

  validate_metadata metadata

  metadata_json = JSON.pretty_generate metadata


  File.open(output_path, 'wb') { |f| f.write output_data }
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

if options.metadata.nil?
  puts 'This program requires the --metadata option to specify the file with badge metadata.'
  return
end

options.badge = "final-#{options.image}" if options.badge.nil?

embed_metadata options.image, options.metadata, options.badge
