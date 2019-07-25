#!/usr/bin/env ruby

require 'fileutils'

pre = Regexp.new(ARGV[0])
post = ARGV[1]

puts "pre\t#{pre.inspect}"
puts "post\t#{post.inspect}"
puts "pwd\t#{Dir.pwd.inspect}"

[true,false].each do |d|

x = Dir.glob('**/*')
x.uniq!

to_rename = x.select{|x| d == File.directory?(x)}.select do |xx|
  xx =~ pre
end.sort.reverse

to_rename.map do |xx|
  newname = xx.gsub(pre,post)
  FileUtils.mkdir_p File.dirname(newname)
  if !File.exist?(newname)
    FileUtils.mv(xx, newname)
    print "Moved"
  elsif !File.directory?(newname) && FileUtils.compare_file(xx, newname)
    FileUtils.mv(xx, newname)
    print "Moved (identical)"
  elsif File.directory?(newname)
    print "Directory exists - noop"
  else
    print "Files differ - not moving"
  end
  puts "\t#{xx.inspect}\t#{newname.inspect}"
end

puts "Done! #{to_rename.size} #{d ? "directories" : "files"} renamed."

end
