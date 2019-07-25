#!/usr/bin/env ruby

require 'fileutils'

pre = Regexp.new(ARGV[0])
post = ARGV[1]

File.open('bulk_rn.log','a') do |f|
f.sync = true
f << "\n\nTime.now.to_s\npre\t#{pre.inspect}\npost\t#{post.inspect}\npwd\t#{Dir.pwd.inspect}"

[true,false].each do |d|

x = Dir.glob('**/*')
x.uniq!

to_rename = x.select{|x| d == File.directory?(x)}.select do |xx|
  xx =~ pre
end.sort.reverse

to_rename.map do |xx|
  newname = xx.gsub(pre,post)
  FileUtils.mkdir_p File.dirname(newname)
  begin
    msg = ""
    if !File.exist?(newname)
      FileUtils.mv(xx, newname)
      msg = "Moved"
    elsif !File.directory?(newname) && FileUtils.compare_file(xx, newname)
      FileUtils.mv(xx, newname)
      msg = "Moved (identical)"
    elsif File.directory?(newname)
      msg = "Directory exists - noop"
    else
      msg = "Files differ - not moving"
    end
    f << "\n#{msg}\t#{xx.inspect}\t#{newname.inspect}"
  rescue => e
    f << "\nerror\t#{xx.inspect}\t#{newname.inspect}\n"
    f << e.message
  end
end

f << "Done! #{to_rename.size} #{d ? "directories" : "files"} renamed."

end

end
