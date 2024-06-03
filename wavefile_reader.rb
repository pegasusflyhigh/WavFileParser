# frozen_string_literal: true

require 'byebug'
require 'builder'
require 'fileutils'
require 'rubocop'

module Config
  RIFF_FILE_TYPE = 'RIFF'
  WAVE_FILE_FORMAT = 'WAVE'
  MIN_FMT_CHUNK_SIZE = 16
  FMT_CHUNK = 'fmt '
end

class WaveFileProcessor
  include Config

  def initialize(directory, output_directory)
    @directory = directory
    @output_directory = output_directory
  end

  def process_directory
    Dir.glob("#{directory}/*.wav") do |wav_file|
      puts "Parsing #{wav_file}"
      process_file(wav_file)
    end
  end

  private

  attr_reader :directory, :output_directory

  def process_file(wav_file)
    File.open(wav_file, 'rb') do |f|
      file_type, file_format = read_file_header(f)
      next unless valid_file_format?(wav_file, file_type, file_format)

      until f.eof?
        chunk_type, chunk_size = read_chunk_header(f)
        if chunk_type == FMT_CHUNK
          next unless valid_fmt_chunk_size?(wav_file, chunk_size)

          data = read_fmt_chunk(f, chunk_size)
          write_xml(wav_file, data)
        else
          f.seek(chunk_size, IO::SEEK_CUR)
        end
      end
    end
  end

  def read_file_header(file)
    file_type = file.read(4)
    file.read(4) # File size
    file_format = file.read(4)
    [file_type, file_format]
  end

  def read_chunk_header(file)
    chunk_type = file.read(4)
    chunk_size = file.read(4).unpack1('V')
    [chunk_type, chunk_size]
  end

  def read_fmt_chunk(file, chunk_size)
    fmt = file.read(chunk_size)
    {
      audio_format: audio_format(fmt[0..1].unpack1('v')),
      channel_count: fmt[2..3].unpack1('v'),
      sampling_rate: fmt[4..7].unpack1('V'),
      byte_rate: fmt[8..11].unpack1('V'),
      bit_depth: fmt[14..15].unpack1('v'),
      bit_rate: fmt[4..7].unpack1('V') * fmt[2..3].unpack1('v') * fmt[14..15].unpack1('v')
    }
  end

  def write_xml(wav_file, data)
    xml_content = xml_builder(data)
    File.write("#{output_directory}/#{File.basename(wav_file, '.wav')}.xml", xml_content)
  end

  def audio_format(value)
    value == 1 ? 'PCM' : 'Compressed'
  end

  def xml_builder(data)
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct! :xml, encoding: 'UTF-8'
    xml.tag!('xs:schema', 'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema') do
      xml.track do
        xml.element(name: 'format', type: 'xs:string', content: data[:audio_format])
        xml.element(name: 'channel_count', type: 'xs:positiveInteger', content: data[:channel_count])
        xml.element(name: 'sampling_rate', type: 'xs:positiveInteger', content: data[:sampling_rate])
        xml.element(name: 'bit_depth', type: 'xs:positiveInteger', content: data[:bit_depth])
        xml.element(name: 'byte_rate', type: 'xs:positiveInteger', minOccurs: '0', content: data[:byte_rate])
        xml.element(name: 'bit_rate', type: 'xs:positiveInteger', content: data[:bit_rate])
      end
    end
  end

  def valid_file_format?(wav_file, file_type, file_format)
    if file_type == RIFF_FILE_TYPE && file_format == WAVE_FILE_FORMAT
      true
    else
      puts "Skipping #{wav_file} as it is not a WAV file!"
      false
    end
  end

  def valid_fmt_chunk_size?(wav_file, chunk_size)
    if chunk_size < MIN_FMT_CHUNK_SIZE
      puts "Skipping #{wav_file} as its fmt chunk size is less than #{MIN_FMT_CHUNK_SIZE} bytes!"
      false
    else
      true
    end
  end
end

def run(directory = ARGV[0])
  raise 'Input must be a directory!' unless File.directory?(directory)

  output_dir = "output/#{Time.now.to_i}"
  FileUtils.mkdir_p(output_dir)

  processor = WaveFileProcessor.new(directory, output_dir)
  processor.process_directory
end

run if __FILE__ == $PROGRAM_NAME
