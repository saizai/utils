#!/usr/bin/env ruby
# Encoding: utf-8

require 'fileutils'
require 'alias_e'
require 'md5sum'

cruft = Regexp.new <<'ENDR'
/(^|.*/)(#
  starting from beginning or something followed by slash
)(Icon|\.DS_Store|desktop\.ini)(#
  Icon and .DS_Store are generated by OSX desktop.ini is generated by Windows
)[[:space:][:blank:][:cntrl:][:punct:]_?]*[^[:print:]]*(#
  They often have random crap at the end.
  Icon in particular tends to have e.g. \r at the end of the filename. This is displayed as ? in many contexts (including terminal).
  Sometimes it is replaced by an actual question mark, space, or underscore.
)$/m
ENDR
# multiline so that it captures \n e.g.; (?n) doesn't always work.


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
  deletable = ARGV[0].sub(/\/$/,'')
  orig = ARGV[1].sub(/\/$/,'')
  unless File.directory?(orig) && File.directory?(deletable)
    puts "#{orig} is not a directory." if !File.directory?(orig)
    puts "#{deletable} is not a directory." if !File.directory?(deletable)
    exit
  end
  unless !File.identical? orig, deletable
    puts "Arguments must be different directories"
    exit
  end
end

def glob_with_dotfiles dir, deep = true
  ff = []
  ff += Dir.glob File.join(dir, '*')
  ff += Dir.glob File.join(dir, '.*')
  if deep
    ff += Dir.glob File.join(dir, '**', '*')
    ff += Dir.glob File.join(dir, '**', '.*')
  end
  ff.reject!{|f| f =~ /[\/^]\.{1,2}$/}
  ff
end


puts "Enumerating files by name..."
orig_ff = glob_with_dotfiles(orig).select{|f| File.file? f}
puts "#{orig_ff.size} files in #{orig}"
deletable_ff = glob_with_dotfiles(deletable).select{|f| File.file? f}
puts "#{deletable_ff.size} files in #{deletable}"

# files_to_check = orig_ff.map{|f| f.sub(/^#{Regexp.escape orig}\//,'')} & deletable_ff.map{|f| f.sub(/^#{Regexp.escape deletable}\//,'')}
# ff_size = files_to_check.size
# puts "#{ff_size} files in both; deleting from #{deletable} if md5-equal to file in #{orig}"
ff_size = deletable_ff.size

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
# files_to_check.each do |f|
deletable_ff.map{|f| f.sub(/^#{Regexp.escape deletable}\//,'')}.each do |f|
  i += 1
  of = File.join(orig, f)
  nf = File.join(deletable, f)
  if prune && f =~ cruft
    pruneable[File.dirname(f)] = '?'
    puts "\t\tx-\t\t#{size_scale size}\t#{f.inspect}"
  else
    if File.file?(nf)
      fs = File.size(nf)
      if File.file?(of)
        begin
            print "#{i}\t#{"%d%%" % (100.0*i/ff_size)}\t"
          if (fs == File.size(of)) && (Digest::MD5.file(of).to_s == Digest::MD5.file(nf).to_s)
            print "="
            pruneable[File.dirname(f)] = '?'
            File.delete(nf)
            size += fs
            deleted += 1
            puts "D\t#{size_scale fs}\t#{size_scale size}\t#{f.inspect}"
          else
            puts "≠\t#{size_scale fs}\t#{size_scale size}\t#{f.inspect}"
          end
        rescue => e
          puts "!\t\t#{size_scale size}\t#{f.inspect}"
          puts e.full_message
        end
      else # in deletable but not in old
        begin
          print ">"
          pruneable[File.dirname(f)] = '?'
          FileUtils.mkdir_p (File.dirname of)
          File.rename(nf, of)
          # size += fs
          deleted += 1
          puts "D\t#{size_scale fs}\t#{size_scale size}\t#{f.inspect}"
        rescue => e
          puts "!\t\t#{size_scale size}\t#{f.inspect}"
          puts e.full_message
        end
      end # file? of
    else
      puts "nf not a file #{nf}"
    end # file? nf
  end # prune
end

if prune
  pruneable[''] = '?'
  pruneable.delete('.')
  while !pruneable.keys.empty?
    dd = pruneable.keys.sort.reverse
    dd_size = dd.size
    puts "#{dd.size} directories to check"
    pruneable = {}
    i=0
    dd.each do |d|
      i+=1
      nd = (d == '' ? deletable : File.join(deletable, d))
      puts "checking #{nd.inspect}"
      if File.directory?(nd)
        print "/"
        glob_with_dotfiles(nd,false).each do |f|
          puts "checking #{f.inspect}"
          if f =~ cruft
            begin
              print "\t\tx"
              pruneable[File.dirname(f)] = '?'
              pruneable[''] = '?'
              File.delete(f)
              deleted += 1
              puts "D\t\t\t#{f.inspect}"
            rescue => e
              puts "!\t\t\t#{f.inspect}"
              puts e.full_message
            end
          end
        end
        if Dir.empty?(nd)
          begin
            print "#{i}\t#{"%d%%" % (100.0*i/dd_size)}\t/"
            parent = File.dirname(nd)
            Dir.rmdir(nd)
            pruneable[parent] = '?'
            pruneable[''] = '?'
            puts "D\t\t\t#{nd.inspect}"
          rescue => e
            puts "!\t\t\t#{nd.inspect}"
            puts e.full_message
          end
        end
      end
    end
  end
end

puts "\n\nDone. #{deleted} files (#{size_scale size}) deleted from #{deletable}."
