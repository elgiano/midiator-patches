#!/usr/bin/env ruby
#
# Add reading capabilities to MIDIator::Interface. Fork a new reading process by 
# calling +start_listening+ and passing a callback process as argument.
#
# == Author
#
# * Gianluca Elia <elgiano@gmail.com>
#
# This code released under the terms of the MIT license.

require 'midiator'
require 'dl/import'

class MIDIator::Interface
  attr_reader :read_data
  # Start listening for MIDI inputs and call +callback+ whenever new data is avaliable ( as +read_data+ )
  def start_listening(callback)
    if callback
      # Thread waiting for data to be available
      Thread.new{
      # Fork a new process to read data
      rd,wr = IO.pipe
      if cpid = fork
        wr.close
        at_exit{Process.kill "KILL",cpid}
        loop do
        IO.select([rd])
        @read_data = rd.gets
        next if not @read_data
        @read_data = @read_data.gsub(/\\n/,"\n").unpack("CCC") # unescape \\n
        callback.call @read_data
        end
      else
        rd.close
        loop do wr.puts read.gsub(/\n/,"\\\\n") end # escape \n
      end
      }
    end
  end
  # Read MIDI inputs. Implemented only for ALSA drivers
  def read
    bytes = @driver.read
    return bytes.to_s(3)
  end
end

class MIDIator::Driver::ALSA < MIDIator::Driver
  module C
    case RUBY_VERSION.to_f
       when 1.8
        extend DL::Importable
       when 1.9
        extend DL::Importer
    end
    dlload 'libasound.so'
    extern "int snd_rawmidi_read(void*, void*, int)"
  end
  
  def read()
    case RUBY_VERSION.to_f
       when 1.8
        @input = DL::PtrData.new(nil)
       when 1.9
        @input = DL::CPtr.new(DL::malloc(DL::TYPE_VOID))
    end
    bytes = [999,999,999].pack("CCC").to_ptr
    C.snd_rawmidi_read(@input,bytes,3)
    C.snd_rawmidi_drain(@input)
    return bytes
  end
end
