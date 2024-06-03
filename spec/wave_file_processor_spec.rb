# frozen_string_literal: true

require_relative '../wavefile_reader'

RSpec.describe 'WaveFileProcessor' do
  let(:test_directory) { 'spec/test_directory' }
  let(:output_directory) { 'spec/test_output' }
  let(:processor) { WaveFileProcessor.new(test_directory, output_directory) }

  before do
    FileUtils.mkdir_p(test_directory)
    FileUtils.mkdir_p(output_directory)

    # Create a dummy WAV file
    File.open("#{test_directory}/test.wav", 'wb') do |f|
      f.write('RIFF')
      f.write([0].pack('V')) # File size placeholder
      f.write('WAVE')
      f.write('fmt ')
      f.write([16].pack('V')) # Chunk size
      f.write([1].pack('v'))  # Audio format (PCM)
      f.write([2].pack('v'))  # Channel count
      f.write([44_100].pack('V')) # Sample rate
      f.write([176_400].pack('V')) # Byte rate
      f.write([4].pack('v')) # Block align
      f.write([16].pack('v')) # Bit depth
    end
  end

  after do
    FileUtils.rm_rf(test_directory)
    FileUtils.rm_rf(output_directory)
  end

  it 'processes the directory without errors' do
    expect { processor.process_directory }.not_to raise_error
  end

  it 'creates an output XML file' do
    processor.process_directory
    expect(Dir.glob("#{output_directory}/*.xml")).not_to be_empty
  end

  context 'when input is not a directory' do
    it 'raises an error' do
      expect { run('test_directory/test.wav') }.to raise_error('Input must be a directory!')
    end
  end

  context 'when a file is not of WAVE format' do
    before do
      File.open("#{test_directory}/flac_test.wav", 'wb') do |f|
        f.write('RIFF')
        f.write([0].pack('V')) # File size placeholder
        f.write('FLAC')
        f.write('fmt ')
      end
    end

    it 'skips that file' do
      processor.process_directory
      expect(Dir.glob("#{output_directory}/flac_test.xml")).to be_empty
    end
  end

  context 'when a file has less chunks of fmt' do
    before do
      File.open("#{test_directory}/no_fmt_test.wav", 'wb') do |f|
        f.write('RIFF')
        f.write([0].pack('v'))
        f.write('WAVE')
        f.write('fmt ')
      end
    end

    it 'skips that file' do
      processor.process_directory
      expect(Dir.glob("#{output_directory}/no_fmt_test.xml")).to be_empty
    end
  end

  context 'when file has no fmt chunk' do
    before do
      File.open("#{test_directory}/no_fmt_test.wav", 'wb') do |f|
        f.write('RIFF')
        f.write([0].pack('v'))
        f.write('WAVE')
        f.write('fmt')
      end
    end

    it 'skips that file' do
      processor.process_directory
      expect(Dir.glob("#{output_directory}/no_fmt_test.xml")).to be_empty
    end
  end
end
