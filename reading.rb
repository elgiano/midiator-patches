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
        @read_data = rd.gets.unpack("CCC")
        callback.call
        end
      else
        rd.close
        loop do wr.puts read end
      end
      }
    end
  end
  # Read MIDI inputs. Implemented only for ALSA drivers
  def read
    @bytes = @driver.read.to_s(3)
    return @bytes.to_s#.unpack("CCC")
  end
end

class MIDIator::Driver::ALSA < MIDIator::Driver
  def read()
    bytes = [999,999,999].pack("CCC").to_ptr
    C.snd_rawmidi_read(@input,bytes,3)
    C.snd_rawmidi_drain(@input)
    return bytes
  end
end
