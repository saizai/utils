#!/usr/bin/env ruby

require 'fileutils'

pre = Regexp.new(ARGV[0])
post = ARGV[1]

puts "pre: #{pre.inspect}"
puts "post: #{post.inspect}"
puts "pwd: #{Dir.pwd.inspect}"

[true,false].each do |d|

x = Dir.glob('**/*')
x.uniq!

to_rename = x.select{|x| d == File.directory?(x)}.select do |xx|
  xx =~ pre
end.sort.reverse

to_rename.map do |xx|
  puts xx
  newname = xx.gsub(pre,post)
  FileUtils.mkdir_p File.dirname(newname)
  if !File.exist?(newname) || FileUtils.compare_file(xx, newname)
    FileUtils.mv(xx, newname)
  else
    puts "Files differ: #{xx}\t#{newname}"
  end
end

puts "Done! #{to_rename.size} #{d ? "directories" : "files"} renamed."

end
