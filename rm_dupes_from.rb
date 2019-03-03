#!/usr/bin/env ruby
# Encoding: utf-8

require 'fileutils'
require 'alias_e'
require 'md5sum'

prune = false

if ARGV.length !=2 && (ARGV.length != 3 && ARGV[0] == "--prune_dirs")
  puts <<-END
Usage: rm_dupes_from [--prune_dirs] dir/with/deletables/ dir/to/keep/

Deletes files from deletables that have the same relative filename, and same md5sum, as a file in keep.

Does not touch files with different name or md5sum. Does not touch files in keep (except to enumerate & md5 them).

Options:
--prune_dirs (Recursively) remove dirs from deletables that became empty due to file deletion. Leaves previously-empty dirs untouched.

Output (tab separated):
[file #] [% of files to check finished] [action code] [file size if deleted] [total size of files deleted] [relative filename]

Codes:
= md5sum was equal
≠ md5sum was not equal
/ (--prune_dirs) directory in deletables empty due to file deletion

D file deleted from deletables
! error deleting file or computing md5sum
END
  exit
else
  if ARGV[0] == "--prune_dirs"
    ARGV.shift
    prune = true
  end
  new = ARGV[0].sub(/\/$/,'')
  orig = ARGV[1].sub(/\/$/,'')
  unless File.directory?(orig) && File.directory?(new)
    puts "Arguments must be directories."
    exit
  end
end

puts "Enumerating files by name..."
orig_ff = Dir.glob("#{orig}/**/**").select{|f| File.file? f}
puts "#{orig_ff.size} files in #{orig}"
new_ff = Dir.glob("#{new}/**/**").select{|f| File.file? f}
puts "#{new_ff.size} files in #{new}"

files_to_check = orig_ff.map{|f| f.sub(/^#{orig}\//,'')} & new_ff.map{|f| f.sub(/^#{new}\//,'')}
ff_size = files_to_check.size
puts "#{ff_size} files in both; deleting from #{new} if md5-equal to file in #{orig}"


def size_scale s
  return s.inspect unless s.is_a? Integer
  if s < 1024*1.5
    "#{s}"
  elsif s < (1024 **2)*1.5
    "#{s/1024} K"
  elsif s < (1024 **3)*1.5
    "#{s/(1024**2)} M"
  else
    "#{s/(1024**3)} G"
  end
end

pruneable = {}
size = 0
i=0
deleted = 0
files_to_check.each do |f|
  i += 1
  of = File.join(orig, f)
  nf = File.join(new, f)
  if File.file?(of) && File.file?(nf)
    begin
      fs = File.size(nf)
      if (fs == File.size(of)) && (Digest::MD5.file(of).to_s == Digest::MD5.file(nf).to_s)
        pruneable[File.dirname(f)] = '?'
        File.delete(nf)
        size += fs
        deleted += 1
        puts "#{i}\t#{"%d%%" % (100.0*i/ff_size)}\t=D\t#{size_scale fs}\t#{size_scale size}\t#{f}"
      else
        puts "#{i}\t#{"%d%%" % (100.0*i/ff_size)}\t≠\t#{size_scale fs}\t#{size_scale size}\t#{f}"
      end
    rescue => e
      puts e.full_message
      puts "#{i}\t#{"%d%%" % (100.0*i/ff_size)}\t=!\t\t#{size_scale size}\t#{f}"
    end
  else
    puts "#{i}\t#{"%d%%" % (100.0*i/ff_size)}\t !\t\t#{size_scale size}\t#{f}"
  end
end

if prune
  while !pruneable.keys.empty?
    dd = pruneable.keys.sort.reverse
    dd_size = dd.size
    puts "#{dd.size} directories to check"
    pruneable = {}
    i=0
    dd.each do |d|
      i+=1
      nd = File.join(new, d)
      if File.directory?(nd) && Dir.empty?(nd)
        begin
          parent = File.dirname(nd)
          Dir.rmdir(nd)
          pruneable[parent] = '?'
          puts "#{i}\t#{"%d%%" % (100.0*i/dd_size)}\t/D\t\t\t#{nd}"
        rescue => e
          puts e.full_message
          puts "#{i}\t#{"%d%%" % (100.0*i/dd_size)}\t/!\t\t\t#{nd}"
        end
      end
    end
  end
end

puts "\n\nDone. #{deleted} files (#{size_scale size}) deleted from #{new}."
