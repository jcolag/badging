# frozen_string_literal: true

require 'base64'
require 'json'
require 'optparse'
require 'ostruct'
require 'zlib'

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
  chunk_type = 'iTXt' # PNG iTXt chunk type for textual data
  metadata_chunk = create_png_chunk chunk_type, "openbadges\u0000\u0000\u0000#{metadata_json}"

  png_signature = "\x89PNG\r\n\x1a\n".b
  output_data = assemble_png(image_data, metadata_chunk, png_signature)

  File.open(output_path, 'wb') { |f| f.write output_data }
  puts "Badge with metadata saved to: #{output_path}"
end

def validate_metadata(metadata)
  required_fields = %w[@context id type issuer validFrom name credentialSchema proof]
  missing_fields = required_fields - metadata.keys
  raise "Metadata missing required fields: #{missing_fields.join(', ')}" unless missing_fields.empty?
end

def create_png_chunk(type, data)
  length = [data.bytesize].pack 'N'
  type_and_data = type + data
  crc = [Zlib.crc32(type_and_data)].pack 'N'
  { length: length, type: type, data: data, crc: crc }
end

def assemble_png(image_data, metadata_chunk, signature)
  raise 'Invalid PNG file format' unless image_data.start_with? signature

  chunks = []
  pos = signature.bytesize
  while pos < image_data.bytesize
    length = image_data[pos, 4].unpack1 'N'
    chunk_type = image_data[pos + 4, 4]
    chunk_data = image_data[pos + 8, length]
    crc = image_data[pos + 8 + length, 4]
    chunks << { length: length, type: chunk_type, data: chunk_data, crc: crc }
    pos += 12 + length
  end

  # Insert metadata chunk before the IEND chunk
  iend_chunk_index = chunks.rindex { |chunk| chunk[:type] == 'IEND' }
  raise 'PNG file missing IEND chunk' unless iend_chunk_index

  chunks.insert iend_chunk_index, {
    length: metadata_chunk[:data].bytesize,
    type: 'iTXt',
    data: metadata_chunk[:data],
    crc: Zlib.crc32(metadata_chunk[:type] + metadata_chunk[:data])
  }

  # Reassemble the PNG file
  signature + chunks.map do |chunk|
    chunk[:length].to_s + chunk[:type] + chunk[:data] + chunk[:crc].to_s
  end.join
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
